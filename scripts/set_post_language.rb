#!/usr/bin/env ruby
# frozen_string_literal: true

# One-shot (#194): `lang: it` and `locale: it_IT` in the front matter of every post whose
# words are Italian (scripts/lib/post_language.rb). _layouts/default.html prints `page.lang`
# in <html lang>, jekyll-seo-tag `locale` in og:locale; without them an Italian post says
# "en" like the rest of the site.
#
#   DRY_RUN=1 ruby scripts/set_post_language.rb   # list what would change, write nothing
#   ruby scripts/set_post_language.rb
#
# A post that already declares `lang` is left as it is, and so is one the detector cannot
# tell (too little text): it keeps the site's default, en. English posts get nothing,
# since en is the default. Re-running it changes nothing. Stdlib only.

require 'yaml'
require 'date'
require_relative 'lib/post_language'

ROOT = File.expand_path('..', __dir__)
DRY = ENV['DRY_RUN'] == '1'

counts = Hash.new(0)
Dir[File.join(ROOT, '_posts', '*')].sort.each do |path|
  text = File.read(path, encoding: 'UTF-8')
  m = text.match(PostLanguage::FRONT_MATTER)
  next unless m

  fm = YAML.safe_load(m[1], permitted_classes: [Date, Time]) || {}
  if fm['lang']
    counts[:declared] += 1
    next
  end

  lang = PostLanguage.of_post(fm, m.post_match)
  counts[lang || :unknown] += 1
  next unless lang == 'it'

  puts "#{DRY ? 'would set' : 'set'} lang: it  #{File.basename(path)}  (#{fm['title']})"
  next if DRY

  File.write(path, "---\n#{m[1]}\nlang: it\nlocale: it_IT\n---\n#{m.post_match}")
end

puts "#{counts['it']} Italian, #{counts['en']} English, #{counts[:unknown]} too short to tell, " \
     "#{counts[:declared]} already declared#{DRY ? ' (dry run)' : ''}"
