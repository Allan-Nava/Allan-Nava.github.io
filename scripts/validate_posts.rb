#!/usr/bin/env ruby
# Validates every post in _posts/: front matter sanity + local asset references.
# Usage: ruby scripts/validate_posts.rb
# Exit code 1 on errors (broken posts), 0 if clean (warnings allowed).
# Stdlib only, so it runs on any Ruby without bundle install.

require 'yaml'
require 'date'
require 'time'

ROOT = File.expand_path('..', __dir__)
CATEGORIES = %w[blog project].freeze
YEAR_RANGE = (2015..(Date.today.year + 1)).freeze

errors = []
warnings = []
tag_usage = Hash.new { |h, k| h[k] = [] }

# The published date as CI sees it: no `timezone` in _config.yml means Jekyll
# reads a bare timestamp as UTC. Returns nil when the value can't be read.
def post_time_utc(raw)
  case raw
  when Time then raw.getutc
  when Date then Time.utc(raw.year, raw.month, raw.day)
  when String
    stamp = raw.strip
    zoned = stamp.match?(/(?:[+-]\d{2}:?\d{2}|[Zz])\z/)
    begin
      (zoned ? Time.parse(stamp) : Time.parse("#{stamp} UTC")).getutc
    rescue ArgumentError
      nil
    end
  end
end

def parse_front_matter(text)
  m = text.match(/\A---\s*\n(.*?)\n---\s*(\n|\z)/m)
  return nil unless m
  yaml = m[1]
  begin
    YAML.safe_load(yaml, permitted_classes: [Date, Time])
  rescue ArgumentError
    # Psych < 3.2 (Ruby 2.6) uses a positional whitelist
    YAML.safe_load(yaml, [Date, Time])
  end
end

authors = begin
  config = begin
    YAML.safe_load(File.read(File.join(ROOT, '_config.yml'), encoding: 'UTF-8'), permitted_classes: [Date, Time])
  rescue ArgumentError
    YAML.safe_load(File.read(File.join(ROOT, '_config.yml'), encoding: 'UTF-8'), [Date, Time])
  end
  (config['authors'] || {}).keys
rescue StandardError => e
  errors << "_config.yml: does not parse as YAML (#{e.message})"
  []
end

posts = Dir[File.join(ROOT, '_posts', '*')].sort
posts.each do |path|
  name = File.basename(path)

  unless name =~ /\A\d{4}-\d{2}-\d{2}-.+\.(markdown|md)\z/
    errors << "#{name}: filename must be YYYY-MM-DD-slug.markdown"
    next
  end

  text = File.read(path, encoding: 'UTF-8')

  begin
    fm = parse_front_matter(text)
  rescue StandardError => e
    errors << "#{name}: front matter is not valid YAML (#{e.message.lines.first.to_s.strip})"
    next
  end

  unless fm.is_a?(Hash)
    errors << "#{name}: missing front matter block (--- ... ---)"
    next
  end

  errors << "#{name}: empty or missing title" if fm['title'].to_s.strip.empty?
  errors << "#{name}: layout must be 'post' (got #{fm['layout'].inspect})" unless fm['layout'] == 'post'

  unless CATEGORIES.include?(fm['category'])
    errors << "#{name}: category must be one of #{CATEGORIES.join('/')} (got #{fm['category'].inspect})"
  end

  if authors.any? && !authors.include?(fm['author'])
    errors << "#{name}: author #{fm['author'].inspect} not defined in _config.yml authors"
  end

  # #162: sui post generati da YouTube una description vuota e' la scelta giusta,
  # non un difetto. La premessa fissa "Video dal canale YouTube di Allan Nava:
  # <titolo>" ripeteva il titolo in quattro punti visibili (meta, feed, card,
  # ricerca); senza il campo, jekyll-seo-tag ricade su `site.description`.
  # Per i post scritti a mano l'avviso resta.
  # `text` e non `body`: quest'ultimo viene assegnato piu' sotto, e in Ruby una
  # variabile locale usata prima della sua assegnazione e' una chiamata a metodo
  # — NameError a runtime.
  generated_video = text.include?('<lite-youtube')
  if fm['description'].to_s.strip.empty? && !generated_video
    warnings << "#{name}: empty description (bad for SEO)"
  end

  # #148: due varianti dello stesso tag (`iOS`/`ios`, `open source`/`open-source`)
  # per Jekyll sono tag diversi ma condividono lo slug, quindi generano due voci
  # nella cloud e due archivi con meta' dei post ciascuno. Si raccolgono qui e si
  # confrontano dopo il ciclo: e' un difetto che esiste solo fra post diversi.
  Array(fm['tag']).each { |t| tag_usage[t.to_s] << name }

  # Date: must parse, and the year must be plausible (catches typos like 22026).
  raw_date = fm['date']
  date =
    case raw_date
    when Date, Time then raw_date
    when String
      begin
        Date.parse(raw_date)
      rescue ArgumentError
        nil
      end
    end
  if date.nil?
    errors << "#{name}: date #{raw_date.inspect} does not parse"
  else
    unless YEAR_RANGE.cover?(date.year)
      errors << "#{name}: date year #{date.year} outside #{YEAR_RANGE} — typo?"
    end
    filename_date = name[0, 10]
    if date.strftime('%Y-%m-%d') != filename_date && YEAR_RANGE.cover?(date.year)
      warnings << "#{name}: front matter date (#{date.strftime('%Y-%m-%d')}) differs from filename date (#{filename_date}) — the URL uses the front matter date"
    end

    # CI reads the front matter date as UTC (_config.yml sets no `timezone`) and
    # Jekyll drops future posts by default: a post dated later today is silently
    # missing from the deployed site — green build, 404 page. Warn while it can
    # still be fixed. Reproduce the CI view with `TZ=UTC bundle exec jekyll build`.
    if (utc = post_time_utc(raw_date)) && utc > Time.now.utc + 60
      warnings << "#{name}: date is in the future in UTC (#{utc.strftime('%Y-%m-%d %H:%M')} UTC) — Jekyll skips it, so the post won't be on the live site until a later build"
    end
  end

  if fm['category'] == 'project' && fm['projects'] != true
    warnings << "#{name}: category 'project' without 'projects: true' — won't appear on /projects"
  end

  # The post header already prints the title as the <h1>: repeating it as the
  # first heading of the body shows it twice, which is what 259 posts did
  # before scripts/dedupe_title_heading.rb (#153). Whitespace-insensitive and
  # case-insensitive, like the one-shot.
  body = text.split(/^---\s*$/, 3)[2].to_s.lstrip
  if (heading = body[/\A\#{1,6}[ \t]*(.+?)[ \t]*\r?$/, 1])
    squash = ->(s) { s.to_s.gsub(/\s+/, ' ').strip.downcase }
    if squash.call(heading) == squash.call(fm['title'])
      warnings << "#{name}: body starts with the title again — the header already prints it as the <h1>"
    end
  end

  # Body checks on the raw text.
  if text =~ %r{github\.com/Allan-Nava/Allan-Nava\.github\.io/blob}
    errors << "#{name}: hotlinks repo files via github.com/...blob — use /assets/... paths instead"
  end

  text.scan(/(?:src|href)="(\/assets\/[^"]+)"/).flatten.uniq.each do |ref|
    rel = ref.sub(/[?#].*\z/, '').sub(%r{\A/}, '')
    if !File.file?(File.join(ROOT, rel))
      errors << "#{name}: references missing file #{rel}"
    elsif rel =~ /\.mov\z/i
      # .MOV files are LFS-tracked; GitHub Pages serves them as pointer files.
      warnings << "#{name}: embeds local LFS video #{rel} — served as a broken pointer on Pages, use YouTube"
    end
  end

  if text =~ %r{(?:github\.com/Allan-Nava/Allan-Nava\.github\.io/raw|media\.githubusercontent\.com)/[^"]*assets/video/}
    warnings << "#{name}: links videos via GitHub raw/media URLs — works but consumes the LFS bandwidth quota; prefer YouTube embeds"
  end
end

# Varianti dello stesso tag (#148): stesso slug, scrittura diversa.
tag_usage.keys.group_by { |t| t.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-|-\z/, '') }
         .each do |slug, variants|
  next if variants.size < 2

  detail = variants.sort.map { |v| "#{v.inspect} (#{tag_usage[v].size})" }.join(' vs ')
  warnings << "tag: #{detail} share the slug '#{slug}' - two clouds and two archives for one topic; " \
              'run scripts/consolidate_tags.rb'
end

puts "Checked #{posts.size} posts."
warnings.each { |w| puts "WARN  #{w}" }
errors.each { |e| puts "ERROR #{e}" }
puts "#{errors.size} error(s), #{warnings.size} warning(s)."
exit(errors.empty? ? 0 : 1)
