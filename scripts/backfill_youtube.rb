#!/usr/bin/env ruby
# One-shot backfill: enumerates EVERY video and short on the YouTube channel
# (paginating the same internal API the web player uses — no personal API key)
# and creates a post for each one not already embedded in _posts/.
# The regular 3-hourly youtube-sync.yml only sees the RSS feed (latest 15);
# this script exists for the long tail. Safe to re-run: it is idempotent.
#
# Usage: ruby scripts/backfill_youtube.rb
#   env HANDLE       — channel handle (default: @allan_nava)
#   env DRY_RUN=1    — only print what would be created
#   env SINCE=YYYY   — skip videos published before this year
#
# Stdlib only — no bundle install needed.

require 'net/http'
require 'json'
require 'date'
require 'uri'

ROOT = File.expand_path('..', __dir__)
HANDLE = ENV.fetch('HANDLE', '@allan_nava')
DRY_RUN = !ENV['DRY_RUN'].to_s.empty?
SINCE = ENV['SINCE'].to_s.empty? ? nil : Integer(ENV['SINCE'])
UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36'
INNERTUBE_KEY = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8' # public web-client key, shipped to every browser

def get(url)
  uri = URI(url)
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
    http.get(uri.request_uri, 'User-Agent' => UA, 'Cookie' => 'SOCS=CAI')
  end
  res.is_a?(Net::HTTPRedirection) ? get(res['location']) : res
end

def browse(continuation)
  uri = URI("https://www.youtube.com/youtubei/v1/browse?key=#{INNERTUBE_KEY}&prettyPrint=false")
  body = {
    context: { client: { clientName: 'WEB', clientVersion: '2.20250101.00.00' } },
    continuation: continuation,
  }.to_json
  Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
    http.post(uri.request_uri, body, 'Content-Type' => 'application/json', 'User-Agent' => UA, 'Cookie' => 'SOCS=CAI')
  end
end

# Walks a channel tab (/videos or /shorts) through all continuation pages.
def enumerate_tab(tab)
  page = get("https://www.youtube.com/#{HANDLE}/#{tab}")
  abort "Cannot load channel #{tab} page: HTTP #{page.code}" unless page.is_a?(Net::HTTPSuccess)
  html = page.body
  ids = html.scan(/"videoId":"([A-Za-z0-9_-]{11})"/).flatten
  token = html[/"continuationCommand":\{"token":"([^"]+)"/, 1]
  pages = 1
  while token && pages < 40
    res = browse(token)
    break unless res.is_a?(Net::HTTPSuccess)
    ids.concat(res.body.scan(/"videoId":"([A-Za-z0-9_-]{11})"/).flatten)
    token = res.body[/"continuationCommand":\{"token":"([^"]+)"/, 1]
    pages += 1
    sleep 0.3
  end
  puts "#{tab}: #{ids.uniq.size} id in #{pages} page(s)"
  ids.uniq
end

# /shorts/<id> answers 200 only for actual shorts (videos redirect to /watch);
# the SOCS cookie skips the EU consent interstitial.
def short?(video_id)
  uri = URI("https://www.youtube.com/shorts/#{video_id}")
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 15) do |http|
    http.head(uri.request_uri, 'User-Agent' => UA, 'Cookie' => 'SOCS=CAI')
  end
  res.code == '200'
rescue StandardError
  false
end

def video_meta(video_id)
  oembed = get("https://www.youtube.com/oembed?url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3D#{video_id}&format=json")
  return nil unless oembed.is_a?(Net::HTTPSuccess) # private/deleted videos
  o = JSON.parse(oembed.body)
  watch = get("https://www.youtube.com/watch?v=#{video_id}")
  upload = watch.is_a?(Net::HTTPSuccess) ? watch.body[/"uploadDate":"([^"]+)"/, 1] : nil
  return nil unless upload
  {
    title: o['title'].to_s.strip,
    short: short?(video_id),
    date: DateTime.parse(upload),
  }
rescue StandardError => e
  warn "  meta error for #{video_id}: #{e.message}"
  nil
end

def slugify(title, fallback)
  slug = title.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')[0, 60].to_s.sub(/-+\z/, '')
  slug.empty? ? fallback.downcase.gsub(/[^a-z0-9]/, '') : slug
end

def yaml_safe(text, max = 160)
  text.to_s.gsub(/\s+/, ' ').delete('"').strip[0, max].strip
end

all_ids = enumerate_tab('videos') + enumerate_tab('shorts')
existing = Dir[File.join(ROOT, '_posts', '*')].map { |f| File.read(f, encoding: 'UTF-8') }.join("\n")
missing = all_ids.uniq.reject { |id| existing.include?(id) }
puts "totale canale: #{all_ids.uniq.size} — già presenti nei post: #{all_ids.uniq.size - missing.size} — da creare: #{missing.size}"

created = 0
missing.each do |id|
  meta = video_meta(id)
  if meta.nil?
    puts "skip (metadata unavailable): #{id}"
    next
  end
  if SINCE && meta[:date].year < SINCE
    puts "skip (before #{SINCE}): #{meta[:title]}"
    next
  end

  kind = meta[:short] ? 'short' : 'video'
  date_part = meta[:date].strftime('%Y-%m-%d')
  base = "#{date_part}-youtube-#{slugify(meta[:title], id)}"
  filename = "#{base}.markdown"
  filename = "#{base}-#{id.downcase.gsub(/[^a-z0-9]/, '')[0, 6]}.markdown" if File.exist?(File.join(ROOT, '_posts', filename))
  path = File.join(ROOT, '_posts', filename)
  short_attr = meta[:short] ? ' data-short' : ''
  hour = meta[:date].hour.zero? && meta[:date].minute.zero? ? '12:00' : meta[:date].strftime('%H:%M')

  post = <<~POST
    ---
    title: "#{yaml_safe(meta[:title], 120)}"
    layout: post
    date: #{date_part} #{hour}
    tag:
    - youtube
    - #{kind}
    image: "https://i.ytimg.com/vi/#{id}/hqdefault.jpg"
    headerImage: false
    description: "Video dal canale YouTube di Allan Nava: #{yaml_safe(meta[:title], 100)}"
    category: blog
    author: allan
    ---

    ## #{meta[:title].delete('#')}

    <lite-youtube videoid="#{id}"#{short_attr} playlabel="#{yaml_safe(meta[:title], 120)}"></lite-youtube>
  POST

  if DRY_RUN
    puts "would create (#{kind}, #{date_part}): #{meta[:title]}"
  else
    File.write(path, post)
    puts "created (#{kind}, #{date_part}): #{filename}"
  end
  created += 1
  sleep 0.3
end

puts "#{created} post#{' (dry run)' if DRY_RUN}."
