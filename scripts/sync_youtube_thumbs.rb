#!/usr/bin/env ruby
# Registra in `thumb:` l'anteprima nel formato originale dei video che NON sono
# 16:9 — Short e altri caricamenti verticali (#163).
#
# Usage: ruby scripts/sync_youtube_thumbs.rb
#   env DRY_RUN=1  — elenca cosa cambierebbe senza scrivere
#
# Il problema: `image:` punta a `hqdefault.jpg`, che YouTube serve **sempre**
# 480x360. Per un video 16:9 dentro c'è il frame nei 270px centrali con due
# bande nere da 45px (misurate); per un verticale c'è il frame al centro e i
# fianchi riempiti con una copia sfocata. Nei listing quel riempimento diventa
# due pannelli ai lati di ogni Short, e su /videos — dove il 56% dei video sono
# Short — è la metà della griglia.
#
# La soluzione: `oardefault.jpg` ("original aspect ratio"), che per i verticali
# è un 1080x1920 pulito. **Esiste solo quando il formato originale non è 16:9**
# e risponde 404 sugli altri, quindi la sua presenza è essa stessa il segnale:
# non serve indovinare l'orientamento. Non si può nemmeno derivare dal tag
# `short`, che sbaglia in 4 casi su 133 (3 Short senza `oardefault`, 1 video
# verticale mai taggato).
#
# Perché un campo nuovo e non `image:`: `image:` è anche l'`og:image`, e
# un'anteprima social 1080x1920 viene ritagliata male da ogni scraper. `thumb:`
# lo usano solo i listing e /videos.
#
# Idempotente: rigirarlo non riscrive niente. Va anche a togliere un `thumb:`
# rimasto su un video che non ha più l'anteprima originale. Stdlib only.

require 'net/http'
require 'uri'
require 'yaml'
require 'date'

ROOT = File.expand_path('..', __dir__)
DRY_RUN = !ENV['DRY_RUN'].to_s.empty?

VIDEO_ID = /<lite-youtube\s+videoid="([A-Za-z0-9_-]{11})"/
def oar_url(id) = "https://i.ytimg.com/vi/#{id}/oardefault.jpg"

# HEAD e non GET: serve solo sapere se esiste, non scaricare 200 KB per 133 video.
def oar_exists?(id)
  uri = URI(oar_url(id))
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 20) do |http|
    http.head(uri.request_uri, 'User-Agent' => 'Mozilla/5.0 (jekyll-youtube-thumbs)')
  end
  res.is_a?(Net::HTTPSuccess)
rescue StandardError => e
  warn "  #{id}: #{e.class} — lo salto, `thumb:` resta com'è"
  nil
end

# Scrittura testuale: rigenerare lo YAML riscriverebbe virgolette e ordine di
# tutte le chiavi. `thumb:` va subito dopo `image:`, che è il campo gemello.
def with_thumb(fm, url)
  lines = fm.lines.reject { |l| l.start_with?('thumb:') }
  at = lines.index { |l| l.start_with?('image:') }
  at = at ? at + 1 : lines.index { |l| l.start_with?('author:') }
  at = at ? at + 1 : lines.size
  lines.insert(at, "thumb: \"#{url}\"\n")
  lines.join
end

def without_thumb(fm)
  fm.lines.reject { |l| l.start_with?('thumb:') }.join
end

added = removed = kept = skipped = plain = 0

Dir[File.join(ROOT, '_posts', '*')].sort.each do |path|
  next if File.directory?(path)

  raw = File.read(path, encoding: 'UTF-8')
  parts = raw.split(/^---\s*$/, 3)
  next if parts.size < 3

  fm_text = parts[1]
  fm = begin
    YAML.safe_load(fm_text, permitted_classes: [Date, Time], aliases: true)
  rescue StandardError
    nil
  end
  next unless fm.is_a?(Hash)

  id = parts[2][VIDEO_ID, 1]
  next unless id

  exists = oar_exists?(id)
  if exists.nil?
    skipped += 1
    next
  end

  current = fm['thumb'].to_s
  name = File.basename(path)

  if exists
    want = oar_url(id)
    if current == want
      kept += 1
      next
    end
    added += 1
    puts "#{name}\n    + thumb: #{want}"
    File.write(path, "---#{with_thumb(fm_text, want)}---#{parts[2]}") unless DRY_RUN
  elsif current.include?('oardefault')
    removed += 1
    puts "#{name}\n    - thumb (oardefault non esiste più per #{id})"
    File.write(path, "---#{without_thumb(fm_text)}---#{parts[2]}") unless DRY_RUN
  else
    plain += 1
  end
end

puts
puts "#{added} thumb aggiunte, #{removed} rimosse#{' (dry run)' if DRY_RUN}."
puts "#{kept} già a posto, #{plain} video 16:9 nativi (nessuna thumb serve)."
puts "#{skipped} saltati per errore di rete." if skipped.positive?
