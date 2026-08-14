#!/usr/bin/env ruby
# Creates a blog post in _posts/ for every recent video/short published on
# the YouTube channel. With YOUTUBE_API_KEY, extracts recording location
# (lat/lng) and adds it to the post front matter for automatic map updates.
# Falls back to RSS feed if no API key (no API key required for basic sync).
# A video is skipped if its ID is already embedded in any existing post, so
# hand-written posts are never duplicated.
#
# Usage: ruby scripts/sync_youtube.rb
#   env CHANNEL_ID       — YouTube channel id (default: Allan's channel)
#   env YOUTUBE_API_KEY  — YouTube Data API key (optional; enables location extraction)
#   env MAX_AGE_DAYS     — only sync videos newer than this (default: 7)
#   env DRY_RUN=1        — print what would be created without writing files
#
# Stdlib only, so it runs on any Ruby without bundle install.

require 'net/http'
require 'rexml/document'
require 'date'
require 'uri'
require 'json'

ROOT = File.expand_path('..', __dir__)
CHANNEL_ID = ENV.fetch('CHANNEL_ID', 'UC1qqsojpiyZB9-u8O02IVVQ')
# .strip: una key incollata con spazi, apici o newline finale fa 400 API_KEY_INVALID.
YOUTUBE_API_KEY = ENV['YOUTUBE_API_KEY'].to_s.strip.gsub(/\A['"]|['"]\z/, '')
MAX_AGE_DAYS = Integer(ENV.fetch('MAX_AGE_DAYS', '7'))
DRY_RUN = !ENV['DRY_RUN'].to_s.empty?

def http_get(url, limit = 5)
  raise 'too many redirects' if limit.zero?
  uri = URI(url)
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
    http.get(uri.request_uri, 'User-Agent' => 'Mozilla/5.0 (jekyll-youtube-sync)')
  end
  case res
  when Net::HTTPRedirection then http_get(res['location'], limit - 1)
  else res
  end
end

# Shorts and regular videos share the same feed; /shorts/<id> answers 200
# only for actual shorts (regular videos redirect to /watch). The SOCS cookie
# skips the EU consent interstitial that would otherwise mask the redirect.
def short?(video_id)
  uri = URI("https://www.youtube.com/shorts/#{video_id}")
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 15) do |http|
    http.head(uri.request_uri, 'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)', 'Cookie' => 'SOCS=CAI')
  end
  res.code == '200'
rescue StandardError
  false
end

def child_text(element, local_name)
  found = nil
  element.each_element { |c| found ||= c if c.name == local_name }
  found && found.text.to_s.strip
end

def slugify(title, fallback)
  slug = title.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')
  slug = slug[0, 60].sub(/-+\z/, '')
  slug.empty? ? fallback.downcase : slug
end

def yaml_safe(text, max = 160)
  text.to_s.gsub(/\s+/, ' ').delete('"').strip[0, max].strip
end

# La descrizione completa del video, come blocco HTML da mettere nel corpo del
# post (la usa `body_description` più sotto).
#
# HTML e non Markdown di proposito: le descrizioni YouTube sono piene di
# `#hashtag`, asterischi, trattini e URL nudi, che in Markdown diventerebbero
# titoli, corsivi ed elenchi a caso. Qui il testo viene escapato, i link resi
# cliccabili e i ritorni a capo conservati.
MAX_DESCRIPTION_CHARS = 1200

def description_html(text)
  body = text.to_s.gsub("\r\n", "\n").strip
  return '' if body.empty?

  body = body[0, MAX_DESCRIPTION_CHARS].rstrip + '…' if body.length > MAX_DESCRIPTION_CHARS

  paragraphs = body.split(/\n{2,}/).map do |paragraph|
    escaped = paragraph.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    escaped = escaped.gsub(%r{(https?://[^\s<]+)}) do
      url = Regexp.last_match(1)
      %(<a href="#{url}" rel="noopener">#{url}</a>)
    end
    "  <p>#{escaped.gsub("\n", "<br>")}</p>"
  end

  "\n<div class=\"video-description\">\n#{paragraphs.join("\n")}\n</div>\n"
end

def geocode_city(city_name)
  return nil if city_name.to_s.empty?

  uri = URI("https://nominatim.openstreetmap.org/search")
  uri.query = URI.encode_www_form(
    'q' => city_name,
    'format' => 'json',
    'limit' => '1'
  )

  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
    http.get(uri.request_uri, 'User-Agent' => 'Mozilla/5.0 (jekyll-youtube-sync)')
  end

  return nil unless res.is_a?(Net::HTTPSuccess)

  data = JSON.parse(res.body)
  return nil if data.empty?

  result = data[0]
  {
    lat: result['lat'].to_f,
    lng: result['lon'].to_f,
    location_name: result['display_name']
  }
rescue StandardError => e
  warn "Warning: could not geocode '#{city_name}': #{e.message}"
  nil
end

def extract_city_from_description(description)
  return nil if description.to_s.empty?

  desc = description.to_s.strip

  if desc =~ /(?:📍|filmed in|shot in|recorded in|in|at|📸 )\s*([A-Z][A-Za-z\s]+(?:,?\s*[A-Z][A-Za-z]*)?)/i
    city = Regexp.last_match(1).strip.sub(/,\s*$/, '')
    return city unless city.empty?
  end

  nil
end

def get_video_location(video_id, api_key, description = '')
  location = nil

  if !api_key.empty?
    location = get_video_location_from_api(video_id, api_key)
  end

  if !location && !description.empty?
    city = extract_city_from_description(description)
    location = geocode_city(city) if city
  end

  location
end

def get_video_location_from_api(video_id, api_key)
  uri = URI("https://www.googleapis.com/youtube/v3/videos")
  uri.query = URI.encode_www_form(
    'id' => video_id,
    'part' => 'recordingDetails',
    'key' => api_key
  )

  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
    http.get(uri.request_uri)
  end

  return nil unless res.is_a?(Net::HTTPSuccess)

  data = JSON.parse(res.body)
  items = data.fetch('items', [])
  return nil if items.empty?

  recording = items[0].fetch('recordingDetails', {})
  location = recording.fetch('location', {})

  if location['latitude'] && location['longitude']
    return {
      lat: location['latitude'],
      lng: location['longitude'],
      location_name: location['locationDescription']
    }
  end

  nil
rescue StandardError => e
  warn "Warning: could not fetch location for #{video_id}: #{e.message}"
  nil
end

# L'HTTP status da solo non basta a capire cosa rifiuta Google: il motivo vero
# (API_KEY_INVALID, quota, API disabilitata, referer non ammesso) sta nel JSON.
def api_error_details(res)
  data = JSON.parse(res.body)
  err = data.fetch('error', {})
  reasons = err.fetch('errors', []).map { |e| e['reason'] }.compact.uniq
  detail = [err['status'], reasons.join(', ')].reject { |s| s.to_s.empty? }.join(' / ')
  [err['message'], detail.empty? ? nil : "(#{detail})"].compact.join(' ')
rescue StandardError
  res.body.to_s[0, 300]
end

def get_videos_from_api(channel_id, api_key, max_age_days)
  abort "YOUTUBE_API_KEY is required to fetch videos" if api_key.empty?

  videos = []
  cutoff = (Date.today - max_age_days).to_s

  uri = URI("https://www.googleapis.com/youtube/v3/search")
  uri.query = URI.encode_www_form(
    'channelId' => channel_id,
    'part' => 'snippet',
    'order' => 'date',
    'maxResults' => '50',
    'publishedAfter' => "#{cutoff}T00:00:00Z",
    'type' => 'video',
    'key' => api_key
  )

  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
    http.get(uri.request_uri)
  end

  unless res.is_a?(Net::HTTPSuccess)
    abort "YouTube API error: HTTP #{res.code} — #{api_error_details(res)}"
  end

  data = JSON.parse(res.body)
  items = data.fetch('items', [])

  items.each do |item|
    video_id = item['id']['videoId']
    snippet = item['snippet']
    videos << {
      video_id: video_id,
      title: snippet['title'],
      description: snippet['description'],
      published_at: snippet['publishedAt']
    }
  end

  videos
end

abort "YOUTUBE_API_KEY is required" if YOUTUBE_API_KEY.empty?

videos = get_videos_from_api(CHANNEL_ID, YOUTUBE_API_KEY, MAX_AGE_DAYS)
existing = Dir[File.join(ROOT, '_posts', '*')].map { |f| File.read(f, encoding: 'UTF-8') }.join("\n")
cutoff = Date.today - MAX_AGE_DAYS
created = []

videos.each do |video|
  video_id = video[:video_id]
  title = video[:title]
  published = video[:published_at]
  description = video[:description].to_s

  time = DateTime.parse(published)
  if time.to_date < cutoff
    puts "skip (older than #{MAX_AGE_DAYS}d): #{title}"
    next
  end
  if existing.include?(video_id)
    puts "skip (already posted):        #{title}"
    next
  end

  is_short = short?(video_id)
  kind = is_short ? 'short' : 'video'
  date_part = time.strftime('%Y-%m-%d')
  filename = "#{date_part}-youtube-#{slugify(title, video_id)}.markdown"
  path = File.join(ROOT, '_posts', filename)
  if File.exist?(path)
    filename = "#{date_part}-youtube-#{slugify(title, video_id)}-#{video_id.downcase.gsub(/[^a-z0-9]/, '')[0, 6]}.markdown"
    path = File.join(ROOT, '_posts', filename)
  end

  desc = yaml_safe(description.lines.first)
  desc = "Video dal canale YouTube di Allan Nava: #{yaml_safe(title, 100)}" if desc.empty?
  body_description = description_html(description)
  short_attr = is_short ? ' data-short' : ''

  location = get_video_location(video_id, YOUTUBE_API_KEY, description)
  # Niente indentazione: `<<~POST` de-indenta solo le righe letterali del
  # sorgente, non il testo interpolato. Con spazi davanti, `lat:`/`lng:`
  # diventerebbero la continuazione dello scalare `author: allan` e il front
  # matter non sarebbe YAML valido.
  location_yaml = if location && location[:lat] && location[:lng]
                     "\nlat: #{location[:lat]}\nlng: #{location[:lng]}"
                   else
                     ''
                   end

  post = <<~POST
    ---
    title: "#{yaml_safe(title, 120)}"
    layout: post
    date: #{time.strftime('%Y-%m-%d %H:%M')}
    tag:
    - youtube
    - #{kind}
    image: "https://i.ytimg.com/vi/#{video_id}/hqdefault.jpg"
    headerImage: false
    description: "#{desc}"
    category: blog
    author: allan#{location_yaml}
    ---

    ## #{title.delete('#')}

    <lite-youtube videoid="#{video_id}"#{short_attr} playlabel="#{yaml_safe(title, 120)}"></lite-youtube>
    #{body_description}
  POST

  if DRY_RUN
    loc_badge = location && location[:lat] && location[:lng] ? ' 📍' : ''
    puts "would create (#{kind}):        #{filename}#{loc_badge}"
  else
    File.write(path, post)
    loc_badge = location && location[:lat] && location[:lng] ? ' 📍' : ''
    puts "created (#{kind}):              #{filename}#{loc_badge}"
  end
  created << filename
end

puts "#{created.size} new post(s)#{' (dry run)' if DRY_RUN}."
