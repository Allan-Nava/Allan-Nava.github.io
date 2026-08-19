#!/usr/bin/env ruby
# Riporta nei post GIÀ pubblicati le località taggate su YouTube, così finiscono
# su /map anche i video geolocalizzati dopo la creazione del post.
#
# Perché serve: `sync_youtube.rb` legge `recordingDetails.location` ma poi salta
# per sempre i video già presenti nei post (`skip (already posted)`). Se la
# località la si aggiunge su YouTube *dopo*, il post resta senza `lat`/`lng` e
# il marker non compare mai. Questo script chiude quel buco.
#
# Usage: ruby scripts/resync_locations.rb
#   env DRY_RUN=1   — dice cosa scriverebbe senza toccare i file
#   env REFRESH=1   — riguarda anche i post che hanno già lat/lng e li aggiorna
#                     se su YouTube la località è cambiata (di default non li
#                     tocca: alcune coordinate sono state messe a mano)
#   env YOUTUBE_API_KEY  — obbligatoria (come per sync_youtube.rb)
#   env YOUTUBE_API_BASE — override dell'endpoint, per i test in locale
#
# Costo di quota: `videos.list` vale 1 unità e accetta 50 id per chiamata, quindi
# l'intero canale sta in 3 chiamate su 10.000 unità al giorno.
#
# Idempotente: rigirarlo non riscrive niente. Stdlib only.

require 'json'
require 'net/http'
require 'uri'
require 'yaml'
require 'date'

ROOT = File.expand_path('..', __dir__)
DRY_RUN  = !ENV['DRY_RUN'].to_s.empty?
REFRESH  = !ENV['REFRESH'].to_s.empty?
API_BASE = ENV.fetch('YOUTUBE_API_BASE', 'https://www.googleapis.com/youtube/v3')

# Le virgolette attorno al valore in un `export` finiscono nella variabile e
# Google risponde 400 su una chiave che *sembra* giusta: via anche quelle.
API_KEY = ENV['YOUTUBE_API_KEY'].to_s.strip.gsub(/\A['"]|['"]\z/, '')
abort 'YOUTUBE_API_KEY is required (same key as sync_youtube.rb).' if API_KEY.empty?

VIDEO_ID = /<lite-youtube\s+videoid="([A-Za-z0-9_-]{11})"/
BATCH = 50

# Lo status HTTP da solo non dice cosa Google stia rifiutando (chiave non valida,
# quota finita, API disattivata, referer non ammesso): il motivo sta nel JSON.
def api_error_details(res)
  data = JSON.parse(res.body)
  err = data.fetch('error', {})
  reasons = err.fetch('errors', []).map { |e| e['reason'] }.compact.uniq
  detail = [err['status'], reasons.join(', ')].reject { |s| s.to_s.empty? }.join(' / ')
  [err['message'], detail.empty? ? nil : "(#{detail})"].compact.join(' ')
rescue StandardError
  res.body.to_s[0, 300]
end

# { video_id => {lat:, lng:, name:} } per i soli video che hanno una località.
def fetch_locations(ids)
  found = {}

  ids.each_slice(BATCH) do |slice|
    uri = URI("#{API_BASE}/videos")
    uri.query = URI.encode_www_form('id' => slice.join(','), 'part' => 'recordingDetails', 'key' => API_KEY)

    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                          open_timeout: 15, read_timeout: 30) do |http|
      http.get(uri.request_uri)
    end

    unless res.is_a?(Net::HTTPSuccess)
      abort "YouTube API error: HTTP #{res.code} — #{api_error_details(res)}"
    end

    items = JSON.parse(res.body).fetch('items', [])
    items.each do |item|
      loc = item.dig('recordingDetails', 'location') || {}
      lat = loc['latitude']
      lng = loc['longitude']
      next unless lat && lng
      # (0, 0) è il "nessuna località" di certi client: in mezzo al golfo di
      # Guinea non c'è nessun video di Allan.
      next if lat.to_f.zero? && lng.to_f.zero?

      found[item['id']] = {
        lat: lat, lng: lng,
        name: item.dig('recordingDetails', 'locationDescription')
      }
    end

    # Chi risponde meno item di quanti id ha ricevuto: video privati, rimossi o
    # id non più validi. Utile saperlo, non è un errore.
    missing = slice - items.map { |i| i['id'] }
    warn "  #{missing.size} video senza risposta (privati o rimossi): #{missing.join(', ')}" if missing.any?
  end

  found
end

# Scrittura testuale sul front matter, non un dump YAML: rigenerare lo YAML
# riscriverebbe virgolette e ordine di tutte le chiavi di ogni post toccato.
# `lat`/`lng` vanno subito dopo `author:`, che è la convenzione di sync_youtube.
def apply(fm, lat, lng)
  lines = fm.lines
  body = lines.reject { |l| l =~ /\A(?:lat|lng):/ }
  at = body.index { |l| l.start_with?('author:') }
  at = at ? at + 1 : body.size
  body.insert(at, "lat: #{lat}\n", "lng: #{lng}\n")
  body.join
end

posts = Dir[File.join(ROOT, '_posts', '*')].sort.reject { |p| File.directory?(p) }
targets = {}   # path => { id:, title:, lat:, lng: }

posts.each do |path|
  raw = File.read(path, encoding: 'UTF-8')
  parts = raw.split(/^---\s*$/, 3)
  next if parts.size < 3

  fm = begin
    YAML.safe_load(parts[1], permitted_classes: [Date, Time], aliases: true)
  rescue StandardError
    nil
  end
  next unless fm.is_a?(Hash)

  id = parts[2][VIDEO_ID, 1]
  next unless id

  has_coords = fm['lat'] && fm['lng']
  next if has_coords && !REFRESH

  targets[path] = { id: id, title: fm['title'].to_s, lat: fm['lat'], lng: fm['lng'] }
end

if targets.empty?
  puts 'Nessun post video da controllare.'
  exit 0
end

puts "#{targets.size} post video da controllare#{REFRESH ? ' (REFRESH: anche quelli già geolocalizzati)' : ' (senza coordinate)'}."
locations = fetch_locations(targets.values.map { |t| t[:id] }.uniq)
puts "#{locations.size} hanno una località taggata su YouTube."
puts

written = 0
unchanged = 0

targets.each do |path, info|
  loc = locations[info[:id]]
  next unless loc

  # Confronto a 7 decimali: l'API restituisce float e ricalcolarli identici non
  # è garantito, ma 1e-7 gradi è circa un centimetro.
  same = info[:lat] && info[:lng] &&
         format('%.7f', info[:lat].to_f) == format('%.7f', loc[:lat].to_f) &&
         format('%.7f', info[:lng].to_f) == format('%.7f', loc[:lng].to_f)
  if same
    unchanged += 1
    next
  end

  name = File.basename(path)
  where = loc[:name].to_s.empty? ? '' : " — #{loc[:name]}"
  change = info[:lat] ? "#{info[:lat]},#{info[:lng]} → " : ''
  puts "#{name}\n    #{info[:title]}\n    #{change}#{loc[:lat]}, #{loc[:lng]}#{where}"

  next if DRY_RUN

  raw = File.read(path, encoding: 'UTF-8')
  parts = raw.split(/^---\s*$/, 3)
  File.write(path, "---#{apply(parts[1], loc[:lat], loc[:lng])}---#{parts[2]}")
  written += 1
end

puts
if DRY_RUN
  changed = locations.keys.count { |id| targets.values.any? { |t| t[:id] == id } } - unchanged
  puts "#{changed} post da aggiornare (dry run), #{unchanged} già allineati."
else
  puts "#{written} post aggiornati, #{unchanged} già allineati."
end
