#!/usr/bin/env ruby
# Creates a blog post in _posts/ for every recent video/short published on
# the YouTube channel, using the channel RSS feed (no API key required).
# A video is skipped if its ID is already embedded in any existing post, so
# hand-written posts are never duplicated.
#
# Usage: ruby scripts/sync_youtube.rb
#   env CHANNEL_ID    — YouTube channel id (default: Allan's channel)
#   env MAX_AGE_DAYS  — only sync videos newer than this (default: 7)
#   env DRY_RUN=1     — print what would be created without writing files
#
# Stdlib only, so it runs on any Ruby without bundle install.

require 'net/http'
require 'rexml/document'
require 'date'
require 'uri'

ROOT = File.expand_path('..', __dir__)
CHANNEL_ID = ENV.fetch('CHANNEL_ID', 'UC1qqsojpiyZB9-u8O02IVVQ')
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

# Shorts and regular videos share the same feed; the oEmbed endpoint reports
# the player dimensions, and only shorts are portrait (height > width).
def short?(video_id)
  res = http_get("https://www.youtube.com/oembed?url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3D#{video_id}&format=json")
  return false unless res.is_a?(Net::HTTPSuccess)
  w = res.body[/"width":(\d+)/, 1].to_i
  h = res.body[/"height":(\d+)/, 1].to_i
  h > w && w.positive?
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

res = http_get("https://www.youtube.com/feeds/videos.xml?channel_id=#{CHANNEL_ID}")
abort "Feed request failed: HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)

doc = REXML::Document.new(res.body)
existing = Dir[File.join(ROOT, '_posts', '*')].map { |f| File.read(f, encoding: 'UTF-8') }.join("\n")
cutoff = Date.today - MAX_AGE_DAYS
created = []

doc.root.each_element do |entry|
  next unless entry.name == 'entry'

  video_id  = child_text(entry, 'videoId')
  title     = child_text(entry, 'title')
  published = child_text(entry, 'published')
  next if video_id.nil? || video_id.empty?

  media = nil
  entry.each_element { |c| media ||= c if c.name == 'group' }
  description = media ? child_text(media, 'description').to_s : ''

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
  width, height = is_short ? [660, 1174] : [560, 315]

  post = <<~POST
    ---
    title: "#{yaml_safe(title, 120)}"
    layout: post
    date: #{time.strftime('%Y-%m-%d %H:%M')}
    tag:
    - youtube
    - #{kind}
    image: ""
    headerImage: false
    description: "#{desc}"
    category: blog
    author: allan
    ---

    ## #{title.delete('#')}

    <iframe width="#{width}" height="#{height}" src="https://www.youtube.com/embed/#{video_id}" title="#{yaml_safe(title, 120)}" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>
  POST

  if DRY_RUN
    puts "would create (#{kind}):        #{filename}"
  else
    File.write(path, post)
    puts "created (#{kind}):              #{filename}"
  end
  created << filename
end

puts "#{created.size} new post(s)#{' (dry run)' if DRY_RUN}."
