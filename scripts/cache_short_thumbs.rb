#!/usr/bin/env ruby
# frozen_string_literal: true

# Small copies of the vertical video thumbnails, for the listing cards (#187).
#
# A vertical video's `thumb:` is YouTube's `oardefault.jpg` (scripts/sync_youtube_thumbs.rb,
# #163): 1080x1920 and up to 500 KB, the only clean vertical thumbnail YouTube serves (its
# smaller `frame0.jpg` is another frame, not the chosen thumbnail). The cards of /blog/ and the
# home show it at about 100px, so a page of Shorts downloaded 1.65 MB of images for ten 100px
# squares: /blog/ scored 79 on Lighthouse, LCP 5.7 s, and the LCP element was one of them.
#
# For each post with such a `thumb:`, this writes assets/images/thumbs/<video id>-270.webp:
# 270px wide (sharp up to a 2.5x screen in a 107px slot), WebP quality 75, 20 to 40 KB.
# _plugins/short_thumbs.rb points the cards at the copy when it exists, and at YouTube when it
# does not yet, so a new Short is never without a thumbnail. /videos/ keeps the original: its
# slots are up to 363px wide.
#
#   ruby scripts/cache_short_thumbs.rb      # only the missing ones; DRY_RUN=1 to list them
#
# Needs `cwebp` on PATH (package webp); image-optimize.yml runs it weekly and commits the new
# files. Idempotent: an existing copy is never fetched again. Stdlib only.

require 'net/http'
require 'uri'
require 'yaml'
require 'date'
require 'fileutils'
require 'tmpdir'

ROOT = File.expand_path('..', __dir__)
OUT = File.join(ROOT, 'assets', 'images', 'thumbs')
WIDTH = 270
QUALITY = 75
OAR = %r{\Ahttps://i\.ytimg\.com/vi/([A-Za-z0-9_-]{6,})/oardefault\.jpg\z}.freeze
DRY = ENV['DRY_RUN'] == '1'

def fetch(url, path, redirects = 3)
  res = Net::HTTP.get_response(URI(url))
  return fetch(res['location'], path, redirects - 1) if res.is_a?(Net::HTTPRedirection) && redirects.positive?
  return :missing if res.is_a?(Net::HTTPNotFound)
  return :error unless res.is_a?(Net::HTTPSuccess)

  File.binwrite(path, res.body)
  :ok
end

ids = Dir[File.join(ROOT, '_posts', '*')].sort.filter_map do |path|
  m = File.read(path, encoding: 'UTF-8').match(/\A---[ \t]*\n(.*?)\n---[ \t]*\n/m)
  next unless m

  fm = YAML.safe_load(m[1], permitted_classes: [Date, Time]) || {}
  fm['thumb'].to_s[OAR, 1]
end.uniq

FileUtils.mkdir_p(OUT) unless DRY
made = 0
failed = []
missing = []
ids.each do |id|
  target = File.join(OUT, "#{id}-#{WIDTH}.webp")
  next if File.exist?(target)

  if DRY
    puts "would make #{File.basename(target)}"
    made += 1
    next
  end

  Dir.mktmpdir do |dir|
    jpg = File.join(dir, "#{id}.jpg")
    case fetch("https://i.ytimg.com/vi/#{id}/oardefault.jpg", jpg)
    when :missing
      # YouTube no longer serves it: the post's `thumb:` is stale, and
      # `FULL=1 ruby scripts/sync_youtube_thumbs.rb` removes it. Not a failure of this script.
      missing << id
      next
    when :error
      failed << id
      next
    end
    if system('cwebp', '-quiet', '-q', QUALITY.to_s, '-resize', WIDTH.to_s, '0', jpg, '-o', target)
      puts "made #{File.basename(target)} (#{File.size(target) / 1024} KB)"
      made += 1
    else
      FileUtils.rm_f(target)
      failed << id
    end
  end
end

puts "#{ids.size} vertical thumbnails, #{made} #{DRY ? 'to make' : 'made'}, #{failed.size} failed#{failed.empty? ? '' : ": #{failed.join(', ')}"}"
puts "#{missing.size} no longer on YouTube (stale `thumb:`, run FULL=1 scripts/sync_youtube_thumbs.rb): #{missing.join(', ')}" unless missing.empty?
exit(failed.empty? ? 0 : 1)
