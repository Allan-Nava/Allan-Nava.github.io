#!/usr/bin/env ruby
# frozen_string_literal: true

# Controllo SEO sul sito compilato: ogni pagina della sitemap, letta da _site/.
#
#   ruby scripts/seo_audit.rb [_site]
#
# Fallisce (exit 1) per quello che una pagina non deve mai perdere:
#   - <title>, <meta name="description">, <link rel="canonical"> (uguale al suo URL), og:image
#   - esattamente un <h1>
#   - un <script type="application/ld+json"> che non e' JSON valido (BlogPosting, Person,
#     VideoObject: un JSON rotto e' un dato strutturato che Google scarta in silenzio)
#   - un <title> oltre 70 caratteri (troncato nei risultati) o una description sotto i 50
#     (#193: _plugins/seo.rb accorcia i titoli dei video e allunga le description corte, quindi
#     una pagina che sfora e' un caso che le sue regole non coprono)
# Avvisa, senza fallire, sui titoli e le description duplicati fra pagine. Il riepilogo va
# anche in $GITHUB_STEP_SUMMARY.
#
# Nato dal crawl del sito live del 2026-11-25 (_plugins/seo.rb ha corretto cio' che aveva
# trovato): serve a non far tornare i duplicati, e a fermare un template che li perde.
# Solo stdlib.

require 'cgi'
require 'json'

SITE = ARGV[0] || '_site'
SITE_URL = 'https://allan-nava.github.io'
TITLE_MAX = 70 # the same limits as SiteSEO::TITLE_MAX and DESCRIPTION_MIN in _plugins/seo.rb
DESC_MIN = 50

sitemap = File.read(File.join(SITE, 'sitemap.xml'))
urls = sitemap.scan(%r{<loc>(.*?)</loc>}m).flatten.map(&:strip)
abort 'seo_audit: no URL in sitemap.xml' if urls.empty?

def file_for(url)
  # The sitemap percent-encodes (apr%C3%A8s-ski); the file on disk has the character.
  path = CGI.unescape(url.delete_prefix(SITE_URL).gsub('+', '%2B'))
  path = '/index.html' if path.empty? || path == '/'
  path += 'index.html' if path.end_with?('/')
  File.join(SITE, path)
end

def first(html, re)
  m = html.match(re)
  m && CGI.unescapeHTML(m[1].strip)
end

errors = []
pages = []
urls.each do |url|
  file = file_for(url)
  unless File.exist?(file)
    errors << "#{url}: no file #{file}"
    next
  end
  html = File.read(file)
  page = {
    url: url,
    title: first(html, %r{<title>(.*?)</title>}m),
    desc: first(html, /<meta name="description" content="([^"]*)"/),
    canonical: first(html, /<link rel="canonical" href="([^"]*)"/),
    og_image: first(html, /<meta property="og:image" content="([^"]*)"/),
    h1: html.scan(/<h1[\s>]/).size,
  }
  pages << page
  errors << "#{url}: no <title>" if page[:title].to_s.empty?
  errors << "#{url}: no meta description" if page[:desc].to_s.empty?
  errors << "#{url}: canonical #{page[:canonical].inspect}, not the page's URL" if page[:canonical] != url
  errors << "#{url}: no og:image" if page[:og_image].to_s.empty?
  errors << "#{url}: #{page[:h1]} <h1>, want 1" if page[:h1] != 1
  errors << "#{url}: title of #{page[:title].length} characters, over #{TITLE_MAX}: #{page[:title].inspect}" if page[:title].to_s.length > TITLE_MAX
  errors << "#{url}: description of #{page[:desc].length} characters, under #{DESC_MIN}: #{page[:desc].inspect}" if page[:desc].to_s.length.between?(1, DESC_MIN - 1)
  html.scan(%r{<script type="application/ld\+json">(.*?)</script>}m).flatten.each do |json|
    JSON.parse(json)
  rescue JSON::ParserError => e
    errors << "#{url}: invalid JSON-LD: #{e.message[0, 120]}"
  end
end

warnings = []
%i[title desc].each do |key|
  pages.group_by { |p| p[key] }.each do |value, group|
    next if value.to_s.empty? || group.size < 2

    warnings << "#{group.size} pages share the #{key == :title ? 'title' : 'description'} #{value[0, 80].inspect}: " +
                group.map { |p| p[:url].delete_prefix(SITE_URL) }.first(4).join(', ')
  end
end

errors.each { |e| puts "error: #{e}" }
warnings.each { |w| puts "warning: #{w}" }
summary = "#{pages.size} pages: #{errors.size} errors, #{warnings.size} warnings"
puts summary

if (out = ENV['GITHUB_STEP_SUMMARY'])
  File.open(out, 'a') do |f|
    f.puts "### SEO audit\n\n#{summary}\n"
    (errors.map { |e| "- error: #{e}" } + warnings.map { |w| "- warning: #{w}" }).first(60).each { |l| f.puts l }
  end
end
exit(errors.empty? ? 0 : 1)
