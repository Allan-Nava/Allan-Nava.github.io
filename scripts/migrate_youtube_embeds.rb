#!/usr/bin/env ruby
# One-shot migration: rewrites every YouTube <iframe> embed in _posts/ to the
# lightweight <lite-youtube> facade (see _includes/youtube-facade.html), so the
# real player only loads on click instead of on page load. Matches the new
# output of sync_youtube.rb / backfill_youtube.rb.
#
# Usage: ruby scripts/migrate_youtube_embeds.rb
#   env DRY_RUN=1  — print what would change without writing files
#
# Idempotent: posts already using <lite-youtube> are left untouched.
# Stdlib only, no bundle install needed.

require 'cgi'

ROOT = File.expand_path('..', __dir__)
DRY_RUN = !ENV['DRY_RUN'].to_s.empty?

IFRAME = %r{<iframe\b[^>]*>\s*</iframe>}im
YT_ID  = %r{/(?:embed|shorts)/([A-Za-z0-9_-]{11})}

def yaml_attr(text, max = 120)
  text.to_s.gsub(/\s+/, ' ').delete('"').strip[0, max].strip
end

changed = 0
iframes = 0
posts = Dir[File.join(ROOT, '_posts', '*')].sort

posts.each do |path|
  src = File.read(path, encoding: 'UTF-8')
  file_iframes = 0

  new_src = src.gsub(IFRAME) do |tag|
    url = tag[/src="([^"]+)"/, 1].to_s
    id  = url[YT_ID, 1]
    next tag unless id # not a YouTube iframe — leave it alone

    file_iframes += 1
    width  = tag[/\bwidth="(\d+)"/, 1]&.to_i
    height = tag[/\bheight="(\d+)"/, 1]&.to_i
    is_short = url.include?('/shorts/') || (width && height && height > width)
    title = yaml_attr(tag[/\btitle="([^"]*)"/, 1])
    short_attr = is_short ? ' data-short' : ''
    label = title.empty? ? '' : %( playlabel="#{title}")
    %(<lite-youtube videoid="#{id}"#{short_attr}#{label}></lite-youtube>)
  end

  next if file_iframes.zero? || new_src == src

  iframes += file_iframes
  changed += 1
  if DRY_RUN
    puts "would migrate (#{file_iframes}): #{File.basename(path)}"
  else
    File.write(path, new_src)
    puts "migrated (#{file_iframes}):      #{File.basename(path)}"
  end
end

puts "#{changed} post, #{iframes} iframe#{' (dry run)' if DRY_RUN}."
