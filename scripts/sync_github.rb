#!/usr/bin/env ruby
# Creates a project post (category: project → listed on /projects) for every
# public GitHub repo of the configured users/orgs. Configuration lives in
# _data/github_sync.yml (sources, filters, exclude list). A repo is skipped
# if its URL already appears in any post, if a `github: <full_name>` marker
# exists, or if the repo name is already part of an existing post filename —
# so hand-written project posts are never duplicated and re-runs are idempotent.
#
# Usage: ruby scripts/sync_github.rb
#   env DRY_RUN=1     — print what would be created without writing files
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

post_files = Dir[File.join(ROOT, '_posts', '*')]
existing_text = post_files.map { |f| File.read(f, encoding: 'UTF-8') }.join("\n")
existing_names = post_files.map { |f| File.basename(f) }.join("\n")
created = 0

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
    if existing_text.include?(repo['html_url']) || existing_text.match?(/^github: #{Regexp.escape(full_name)}$/i)
      puts "skip (already posted):   #{full_name}"
      next
    end
    slug = slugify(name)
    if slug.length >= 5 && existing_names.include?(slug)
      puts "skip (filename match):   #{full_name} — esiste già un post con '#{slug}' nel nome"
      next
    end

    time = DateTime.parse(repo['created_at'])
    tags = [repo['language']].compact.map(&:downcase) + repo.fetch('topics', []).first(3)
    tags = ['github'] if tags.empty?
    stars = repo['stargazers_count'].to_i

    filename = "#{time.strftime('%Y-%m-%d')}-github-#{slug}.markdown"
    path = File.join(ROOT, '_posts', filename)
    next if File.exist?(path)

    body_lines = ["- **Owner**: [#{full_name.split('/').first}](https://github.com/#{full_name.split('/').first})"]
    body_lines << "- **Linguaggio**: #{repo['language']}" if repo['language']
    body_lines << "- **Stars**: #{stars}" if stars.positive?

    post = <<~POST
      ---
      title: "#{yaml_safe(name, 120)}"
      layout: post
      date: #{time.strftime('%Y-%m-%d %H:%M')}
      tag:
      #{tags.map { |t| "- #{yaml_safe(t, 40)}" }.join("\n")}
      image: ""
      headerImage: false
      projects: true
      hidden: true
      description: "#{yaml_safe(description.empty? ? "Repository GitHub: #{full_name}" : description)}"
      category: project
      author: allan
      externalLink: https://github.com/#{full_name}
      github: #{full_name}
      ---

      ## #{name}

      #{description}

      #{body_lines.join("\n")}

      [Repo su GitHub →](https://github.com/#{full_name})
    POST

    if DRY_RUN
      puts "would create: #{filename}"
    else
      File.write(path, post)
      puts "created: #{filename}"
    end
    created += 1
  end
end

puts "#{created} new project post(s)#{' (dry run)' if DRY_RUN}."
