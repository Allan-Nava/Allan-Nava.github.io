#!/usr/bin/env ruby
# GitHub repos → skills. Reads the public repositories of the sources in _data/github_sync.yml
# (the same ones that become posts on /projects), finds the skills each one shows through
# _data/skills_map.yml (primary language and topics), and writes _data/skills_repos.yml:
#
#   skills:  every mapped skill, with the repos that use it, newest push first — /stack/
#            lists them under a skill of _data/skills.yml as "Also in …"
#   groups:  per group of _data/skills.yml, the skills that file does not have yet, so the home
#            grid and /stack/ show them too, marked as own projects (or work, when every repo
#            using it belongs to the hiway-media organisation)
#
# _data/skills.yml stays hand-written: this script never touches it. A skill that the script
# added and that deserves a real line of detail is written into skills.yml by hand, with the
# same name; from the next run it is no longer listed under `groups`.
#
# Forks, archived repos, repos without a description and the exclude list of github_sync.yml
# are left out, as for the project posts. The file is rewritten only when its content changes,
# so an idle run leaves no diff.
#
# Usage: ruby scripts/sync_skills.rb
#   env DRY_RUN=1     print the result without writing
#   env GITHUB_TOKEN  raises the API rate limit (set in CI)
#
# Stdlib only — no bundle install needed.

require 'net/http'
require 'json'
require 'yaml'
require 'uri'

ROOT = File.expand_path('..', __dir__)
DRY_RUN = !ENV['DRY_RUN'].to_s.empty?
TOKEN = ENV['GITHUB_TOKEN'].to_s
OUT = File.join(ROOT, '_data', 'skills_repos.yml')

def load_yaml(name)
  YAML.safe_load(File.read(File.join(ROOT, '_data', name), encoding: 'UTF-8'))
end

sync = load_yaml('github_sync.yml')
map = load_yaml('skills_map.yml')
curated = load_yaml('skills.yml')

SOURCES = sync.fetch('sources', [])
EXCLUDE = sync.fetch('exclude', []).map(&:downcase)
REQUIRE_DESCRIPTION = sync.fetch('require_description', true)
LANGUAGES = map.fetch('languages', {})
TOPICS = map.fetch('topics', {})
IGNORE = map.fetch('ignore', []).map(&:downcase)

# name → group id of every hand-written skill
CURATED = {}
curated.fetch('groups', []).each do |g|
  g.fetch('items', []).each { |s| CURATED[s['name']] = g['id'] }
end
GROUP_IDS = curated.fetch('groups', []).map { |g| g['id'] }

(LANGUAGES.values + TOPICS.values).each do |m|
  abort "skills_map.yml: group '#{m['group']}' of '#{m['skill']}' is not in skills.yml" unless GROUP_IDS.include?(m['group'])
end

def get_json(url)
  uri = URI(url)
  headers = { 'User-Agent' => 'jekyll-skills-sync', 'Accept' => 'application/vnd.github+json' }
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
    batch = get_json("https://api.github.com/#{base}/repos?per_page=100&page=#{page}")
    repos.concat(batch)
    break if batch.size < 100
  end
  repos.map { |r| r.merge('work' => source.key?('org')) }
end

repos = SOURCES.flat_map { |s| all_repos(s) }.reject do |r|
  r['fork'] || r['archived'] || r['private'] ||
    EXCLUDE.include?(r['full_name'].downcase) ||
    (REQUIRE_DESCRIPTION && r['description'].to_s.strip.empty?)
end

found = Hash.new { |h, k| h[k] = { 'group' => nil, 'repos' => [] } }
unmapped = Hash.new(0)

repos.each do |r|
  keys = []
  lang = r['language']
  if lang
    if LANGUAGES[lang] then keys << LANGUAGES[lang]
    elsif !IGNORE.include?(lang.downcase) then unmapped["language #{lang}"] += 1
    end
  end
  Array(r['topics']).each do |t|
    if TOPICS[t] then keys << TOPICS[t]
    elsif !IGNORE.include?(t.downcase) then unmapped["topic #{t}"] += 1
    end
  end
  keys.uniq { |m| m['skill'] }.each do |m|
    entry = found[m['skill']]
    entry['group'] = CURATED[m['skill']] || m['group']
    entry['repos'] << {
      'name' => r['name'],
      'url' => r['html_url'],
      'pushed' => r['pushed_at'].to_s[0, 10],
      'work' => r['work']
    }
  end
end

skills = {}
found.keys.sort_by(&:downcase).each do |name|
  entry = found[name]
  list = entry['repos'].sort_by { |x| [x['pushed'], x['name']] }.reverse
  skills[name] = {
    'group' => entry['group'],
    'curated' => CURATED.key?(name),
    'where' => list.all? { |x| x['work'] } ? 'work' : 'projects',
    'repos' => list.map { |x| x.reject { |k, _| k == 'work' } }
  }
end

groups = {}
GROUP_IDS.each do |gid|
  extra = skills.select { |_, s| !s['curated'] && s['group'] == gid }
  next if extra.empty?

  groups[gid] = extra.map do |name, s|
    names = s['repos'].first(3).map { |x| x['name'] }
    more = s['repos'].size - names.size
    detail = "In my public repositories: #{names.join(', ')}#{more.positive? ? " and #{more} more" : ''}"
    { 'name' => name, 'where' => s['where'], 'detail' => detail, 'repos' => s['repos'] }
  end
end

header = <<~TXT
  # GENERATED by scripts/sync_skills.rb from the public GitHub repositories and
  # _data/skills_map.yml — do not edit. The hand-written skills are in _data/skills.yml.
TXT
body = { 'skills' => skills, 'groups' => groups }
content = header + body.to_yaml(line_width: -1).sub(/\A---\n/, '')

added = groups.values.flatten.map { |s| s['name'] }
puts "#{repos.size} repos, #{skills.size} skills (#{skills.count { |_, s| s['curated'] }} in skills.yml, #{added.size} added: #{added.join(', ')})"
unless unmapped.empty?
  puts 'unmapped (add to _data/skills_map.yml, or to its ignore list):'
  unmapped.sort_by { |k, v| [-v, k] }.each { |k, v| puts "  #{k}: #{v} repo#{v == 1 ? '' : 's'}" }
end

if DRY_RUN
  puts content
elsif File.exist?(OUT) && File.read(OUT, encoding: 'UTF-8') == content
  puts "#{File.basename(OUT)}: unchanged"
else
  File.write(OUT, content)
  puts "#{File.basename(OUT)}: written"
end
