#!/usr/bin/env ruby
# Creates a blog post for every recent Strava activity (hike, climb, ride...).
# An activity is skipped if its ID is already linked in any existing post, so
# re-runs are idempotent and hand-written posts are never duplicated.
#
# Requires a Strava API app (https://www.strava.com/settings/api) and env:
#   STRAVA_CLIENT_ID, STRAVA_CLIENT_SECRET, STRAVA_REFRESH_TOKEN
# Optional env:
#   ACTIVITY_TYPES — comma-separated sport types to sync
#                    (default: Hike,RockClimbing,TrailRun,Snowboard,AlpineSki)
#   MAX_AGE_DAYS   — only sync activities newer than this (default: 7)
#   DRY_RUN=1      — print what would be created without writing files
#
# Setup (one-time, to obtain the refresh token) is documented in
# docs/deployment.md. Stdlib only — no bundle install needed.

require 'net/http'
require 'json'
require 'date'
require 'uri'

ROOT = File.expand_path('..', __dir__)
CLIENT_ID = ENV['STRAVA_CLIENT_ID'].to_s
CLIENT_SECRET = ENV['STRAVA_CLIENT_SECRET'].to_s
REFRESH_TOKEN = ENV['STRAVA_REFRESH_TOKEN'].to_s
TYPES = ENV.fetch('ACTIVITY_TYPES', 'Hike,RockClimbing,TrailRun,Snowboard,AlpineSki').split(',').map(&:strip)
MAX_AGE_DAYS = Integer(ENV.fetch('MAX_AGE_DAYS', '7'))
DRY_RUN = !ENV['DRY_RUN'].to_s.empty?

if [CLIENT_ID, CLIENT_SECRET, REFRESH_TOKEN].any?(&:empty?)
  puts 'Strava secrets not configured (STRAVA_CLIENT_ID / STRAVA_CLIENT_SECRET / STRAVA_REFRESH_TOKEN) — nothing to do.'
  exit 0
end

def post_form(url, params)
  uri = URI(url)
  Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
    req = Net::HTTP::Post.new(uri.request_uri)
    req.set_form_data(params)
    http.request(req)
  end
end

def get_json(url, token)
  uri = URI(url)
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
    http.get(uri.request_uri, 'Authorization' => "Bearer #{token}")
  end
  abort "Strava API error: HTTP #{res.code} #{res.body[0, 200]}" unless res.is_a?(Net::HTTPSuccess)
  JSON.parse(res.body)
end

def slugify(text, fallback)
  slug = text.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')[0, 60].to_s.sub(/-+\z/, '')
  slug.empty? ? fallback : slug
end

def yaml_safe(text, max = 160)
  text.to_s.gsub(/\s+/, ' ').delete('"').strip[0, max].strip
end

def duration_hm(seconds)
  h, m = seconds.to_i / 3600, (seconds.to_i % 3600) / 60
  h.positive? ? format('%dh %02dm', h, m) : format('%dm', m)
end

SPORT_LABELS = {
  'Hike' => 'Escursione', 'RockClimbing' => 'Arrampicata', 'TrailRun' => 'Trail run',
  'Snowboard' => 'Snowboard', 'AlpineSki' => 'Sci', 'Ride' => 'Bici', 'Run' => 'Corsa',
}.freeze

token_res = post_form('https://www.strava.com/oauth/token',
                      'client_id' => CLIENT_ID, 'client_secret' => CLIENT_SECRET,
                      'grant_type' => 'refresh_token', 'refresh_token' => REFRESH_TOKEN)
abort "Strava token refresh failed: HTTP #{token_res.code} #{token_res.body[0, 200]}" unless token_res.is_a?(Net::HTTPSuccess)
access_token = JSON.parse(token_res.body).fetch('access_token')

activities = get_json('https://www.strava.com/api/v3/athlete/activities?per_page=50', access_token)
existing = Dir[File.join(ROOT, '_posts', '*')].map { |f| File.read(f, encoding: 'UTF-8') }.join("\n")
cutoff = Date.today - MAX_AGE_DAYS
created = 0

activities.each do |act|
  sport = act['sport_type'] || act['type']
  id = act['id'].to_s
  name = act['name'].to_s.strip
  time = DateTime.parse(act['start_date_local'])

  next unless TYPES.include?(sport)
  if time.to_date < cutoff
    puts "skip (older than #{MAX_AGE_DAYS}d): #{name}"
    next
  end
  if existing.include?("strava.com/activities/#{id}")
    puts "skip (already posted):        #{name}"
    next
  end

  label = SPORT_LABELS.fetch(sport, sport)
  km = (act['distance'].to_f / 1000).round(1)
  dplus = act['total_elevation_gain'].to_f.round
  moving = duration_hm(act['moving_time'])

  date_part = time.strftime('%Y-%m-%d')
  filename = "#{date_part}-strava-#{slugify(name, id)}.markdown"
  path = File.join(ROOT, '_posts', filename)
  if File.exist?(path)
    filename = "#{date_part}-strava-#{slugify(name, id)}-#{id[-6..]}.markdown"
    path = File.join(ROOT, '_posts', filename)
  end

  post = <<~POST
    ---
    title: "#{yaml_safe(name, 120)}"
    layout: post
    date: #{time.strftime('%Y-%m-%d %H:%M')}
    tag:
    - strava
    - #{slugify(label, sport.downcase)}
    image: ""
    headerImage: false
    description: "#{label} su Strava: #{km} km, #{dplus} m D+, #{moving} in movimento."
    category: blog
    author: allan
    ---

    ## #{name.delete('#')}

    | | |
    |---|---|
    | **Attività** | #{label} |
    | **Distanza** | #{km} km |
    | **Dislivello** | #{dplus} m D+ |
    | **Tempo in movimento** | #{moving} |

    [Vedi l'attività su Strava →](https://www.strava.com/activities/#{id})
  POST

  if DRY_RUN
    puts "would create (#{sport}): #{filename}"
  else
    File.write(path, post)
    puts "created (#{sport}): #{filename}"
  end
  created += 1
end

puts "#{created} new post(s)#{' (dry run)' if DRY_RUN}."
