#!/usr/bin/env ruby
# Validates every post in _posts/: front matter sanity + local asset references.
# Usage: ruby scripts/validate_posts.rb
# Exit code 1 on errors (broken posts), 0 if clean (warnings allowed).
# Stdlib only, so it runs on any Ruby without bundle install.

require 'yaml'
require 'date'

ROOT = File.expand_path('..', __dir__)
CATEGORIES = %w[blog project].freeze
YEAR_RANGE = (2015..(Date.today.year + 1)).freeze

errors = []
warnings = []

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

  warnings << "#{name}: empty description (bad for SEO)" if fm['description'].to_s.strip.empty?

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
  end

  if fm['category'] == 'project' && fm['projects'] != true
    warnings << "#{name}: category 'project' without 'projects: true' — won't appear on /projects"
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

puts "Checked #{posts.size} posts."
warnings.each { |w| puts "WARN  #{w}" }
errors.each { |e| puts "ERROR #{e}" }
puts "#{errors.size} error(s), #{warnings.size} warning(s)."
exit(errors.empty? ? 0 : 1)
