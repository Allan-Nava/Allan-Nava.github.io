#!/usr/bin/env ruby
# Syncs public GitHub repos of the configured users/orgs into project posts
# (category: project → listed on /projects). Configuration lives in
# _data/github_sync.yml (sources, filters, exclude list).
#
# Two things happen per run:
#   1. CREATE — a repo with no post yet gets one. A repo is skipped if its URL
#      already appears in any post, if a `github: <full_name>` marker exists,
#      or if the repo name is already part of an existing post filename — so
#      hand-written posts are never duplicated.
#   2. UPDATE — a repo that already has a *generated* post (identified by its
#      `github: <full_name>` marker) is refreshed when the repo changed: the
#      post tracks the repo's last push (`updated:` front matter + "Ultimo
#      push" line), description, language, topics and stars. This is how the
#      hourly run reacts to pushes on existing repos. Hand-written posts (no
#      marker) are never touched. Files are rewritten only when the content
#      actually changes, so an idle run produces no diff (no commit, no deploy).
#
# The original `date:` (and therefore the post URL) is always preserved on
# update — only `updated:` and metadata move.
#
# Usage: ruby scripts/sync_github.rb
#   env DRY_RUN=1     — print what would change without writing files
#   env GITHUB_TOKEN  — optional, raises the API rate limit (set in CI)
#
# Stdlib only — no bundle install needed.

require 'net/http'
require 'json'
require 'yaml'
require 'date'
require 'uri'

ROOT = File.expand_path('..', __dir__)
DRY_RUN = !ENV['DRY_RUN'].to_s.empty?
TOKEN = ENV['GITHUB_TOKEN'].to_s

config = YAML.safe_load(File.read(File.join(ROOT, '_data', 'github_sync.yml'), encoding: 'UTF-8'))
SOURCES = config.fetch('sources', [])
REQUIRE_DESCRIPTION = config.fetch('require_description', true)
MIN_STARS = config.fetch('min_stars', 0).to_i
EXCLUDE = config.fetch('exclude', []).map(&:downcase)

def get_json(url)
  uri = URI(url)
  headers = { 'User-Agent' => 'jekyll-github-sync', 'Accept' => 'application/vnd.github+json' }
  headers['Authorization'] = "Bearer #{TOKEN}" unless TOKEN.empty?
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
    http.get(uri.request_uri, headers)
  end
  abort "GitHub API error: HTTP #{res.code} for #{url}" unless res.is_a?(Net::HTTPSuccess)
  JSON.parse(res.body)
end

def all_repos(source)
  base = source.key?('org') ? "orgs/#{source['org']}" : "users/#{source['user']}"
  repos = []
  (1..10).each do |page|
    batch = get_json("https://api.github.com/#{base}/repos?per_page=100&page=#{page}&sort=created")
    repos.concat(batch)
    break if batch.size < 100
  end
  repos
end

def slugify(text)
  text.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')[0, 60].sub(/-+\z/, '')
end

def yaml_safe(text, max = 160)
  text.to_s.gsub(/\s+/, ' ').delete('"').strip[0, max].strip
end

# Estensioni accettate. L'ordine conta: png/jpg/webp prima di svg e gif perché
# l'immagine finisce anche in `og:image`, e i social non renderizzano gli SVG.
RASTER_EXT = %w[png jpg jpeg webp].freeze
VECTOR_EXT = %w[svg gif].freeze
IMAGE_EXT = (RASTER_EXT + VECTOR_EXT).freeze

# Un README di progetto è pieno di badge: shields.io, il badge dei workflow,
# codecov, il Marketplace… Sono immagini valide ma come copertina non dicono
# nulla, e prima erano proprio loro a vincere (il primo `![...]()` del file).
BADGE_PATTERNS = [
  %r{//img\.shields\.io/}i,
  %r{//shields\.io/}i,
  %r{//badgen\.net/}i,
  %r{//codecov\.io/}i,
  %r{//coveralls\.io/}i,
  %r{//app\.travis-ci\.}i,
  %r{//circleci\.com/}i,
  %r{//api\.netlify\.com/}i,
  %r{badge}i,          # .../ci.yml/badge.svg, badge.png, /badges/...
  %r{/workflows/.+/badge}i
].freeze

def badge?(url)
  BADGE_PATTERNS.any? { |pattern| url =~ pattern }
end

# Estensione dell'immagine ignorando query string e ancora
# (`logo.png?raw=true`, `logo.svg#gh-dark-mode-only`).
def image_ext(url)
  path = url.split(/[?#]/).first.to_s
  ext = File.extname(path).delete('.').downcase
  IMAGE_EXT.include?(ext) ? ext : nil
end

def absolute_image_url(url, full_name, branch)
  return url if url =~ %r{\Ahttps?://}i

  path = url.sub(%r{\A\./}, '').sub(%r{\A/}, '')
  "https://raw.githubusercontent.com/#{full_name}/#{branch}/#{path}"
end

# Primo logo "vero" del README, o nil.
#
# Cerca sia la sintassi Markdown `![alt](url)` sia i tag `<img src="…">`: i
# README di questo autore mettono il logo in HTML dentro un blocco centrato,
# quindi la versione che guardava solo il Markdown non trovava mai nulla.
def get_repo_image(full_name, branch = 'main')
  uri = URI("https://api.github.com/repos/#{full_name}/readme")
  headers = { 'User-Agent' => 'jekyll-github-sync', 'Accept' => 'application/vnd.github.v3.raw' }
  headers['Authorization'] = "Bearer #{TOKEN}" unless TOKEN.empty?
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
    http.get(uri.request_uri, headers)
  end
  return nil unless res.is_a?(Net::HTTPSuccess)

  readme = res.body.to_s

  # `![alt](url "titolo")` e `<img src="url">`, nell'ordine in cui compaiono.
  candidates = readme.scan(/!\[[^\]]*\]\(\s*<?([^)\s"']+)>?(?:\s+["'][^"']*["'])?\s*\)/i).flatten
  candidates += readme.scan(/<img[^>]+src\s*=\s*["']([^"']+)["']/i).flatten

  usable = candidates.reject { |url| badge?(url) }.select { |url| image_ext(url) }
  return nil if usable.empty?

  # A parità di posizione, meglio un raster: l'immagine è anche og:image.
  best = usable.find { |url| RASTER_EXT.include?(image_ext(url)) } || usable.first
  absolute_image_url(best, full_name, branch)
rescue StandardError => e
  warn "Warning: could not fetch image for #{full_name}: #{e.message}"
  nil
end

# Builds the full post file content for a repo. `date_str` is the front-matter
# date to use (created_at for new posts, the preserved original on update).
def build_post(repo, date_str, image = nil)
  full_name = repo['full_name']
  name = repo['name']
  owner = full_name.split('/').first
  description = repo['description'].to_s.strip
  stars = repo['stargazers_count'].to_i
  pushed = repo['pushed_at'] ? DateTime.parse(repo['pushed_at']).strftime('%Y-%m-%d') : nil
  tags = [repo['language']].compact.map(&:downcase) + repo.fetch('topics', []).first(3)
  tags = ['github'] if tags.empty?

  front = []
  front << %(title: "#{yaml_safe(name, 120)}")
  front << 'layout: post'
  front << "date: #{date_str}"
  front << "updated: #{pushed}" if pushed
  front << 'tag:'
  tags.each { |t| front << "- #{yaml_safe(t, 40)}" }
  front << %(image: "#{image || ''}")
  front << 'headerImage: false'
  front << 'projects: true'
  front << 'hidden: true'
  front << %(description: "#{yaml_safe(description.empty? ? "Repository GitHub: #{full_name}" : description)}")
  front << 'category: project'
  front << 'author: allan'
  front << "externalLink: https://github.com/#{full_name}"
  front << "github: #{full_name}"

  body = ["- **Owner**: [#{owner}](https://github.com/#{owner})"]
  body << "- **Linguaggio**: #{repo['language']}" if repo['language']
  body << "- **Stars**: #{stars}" if stars.positive?
  body << "- **Ultimo push**: #{pushed}" if pushed

  <<~POST
    ---
    #{front.join("\n")}
    ---

    ## #{name}

    #{description}

    #{body.join("\n")}

    [Repo su GitHub →](https://github.com/#{full_name})
  POST
end

post_files = Dir[File.join(ROOT, '_posts', '*')]
existing_text = post_files.map { |f| File.read(f, encoding: 'UTF-8') }.join("\n")
existing_names = post_files.map { |f| File.basename(f) }.join("\n")

# Map generated posts by their `github:` marker → { path, date, content } so we
# can update them in place while preserving the original date (and URL).
generated = {}
post_files.each do |f|
  content = File.read(f, encoding: 'UTF-8')
  marker = content[/^github:\s*(\S+)\s*$/, 1]
  next unless marker
  date = content[/^date:\s*(.+?)\s*$/, 1]
  generated[marker.downcase] = { path: f, date: date, content: content }
end

created = 0
updated = 0

SOURCES.each do |source|
  label = source['org'] || source['user']
  repos = all_repos(source)
  puts "#{label}: #{repos.size} repo"

  repos.each do |repo|
    full_name = repo['full_name']
    name = repo['name']
    next if repo['fork']
    next if EXCLUDE.include?(full_name.downcase)
    description = repo['description'].to_s.strip
    if REQUIRE_DESCRIPTION && description.empty?
      puts "skip (no description):   #{full_name}"
      next
    end
    if repo['stargazers_count'].to_i < MIN_STARS
      puts "skip (< #{MIN_STARS} stars):     #{full_name}"
      next
    end

    # Il branch di default va letto dal repo: assumere "main" rompeva i raw URL
    # dei repo ancora su master.
    image = get_repo_image(full_name, repo['default_branch'].to_s.empty? ? 'main' : repo['default_branch'])

    # Already have a generated post for this repo → refresh it if it changed.
    gp = generated[full_name.downcase]
    if gp
      new_content = build_post(repo, gp[:date], image)
      if new_content.strip == gp[:content].strip
        # unchanged since last run — no-op
      elsif DRY_RUN
        puts "would update:            #{File.basename(gp[:path])}"
        updated += 1
      else
        File.write(gp[:path], new_content)
        puts "updated:                 #{File.basename(gp[:path])}"
        updated += 1
      end
      next
    end

    # No marker for this repo: don't duplicate a hand-written post that already
    # links it, and don't collide with an existing filename slug.
    if existing_text.include?(repo['html_url'])
      puts "skip (already linked):   #{full_name}"
      next
    end
    slug = slugify(name)
    if slug.length >= 5 && existing_names.include?(slug)
      puts "skip (filename match):   #{full_name} — esiste già un post con '#{slug}' nel nome"
      next
    end

    time = DateTime.parse(repo['created_at'])
    filename = "#{time.strftime('%Y-%m-%d')}-github-#{slug}.markdown"
    path = File.join(ROOT, '_posts', filename)
    next if File.exist?(path)

    content = build_post(repo, time.strftime('%Y-%m-%d %H:%M'), image)
    if DRY_RUN
      puts "would create:            #{filename}"
    else
      File.write(path, content)
      puts "created:                 #{filename}"
    end
    created += 1
  end
end

puts "#{created} new, #{updated} updated#{' (dry run)' if DRY_RUN}."
