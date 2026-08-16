#!/usr/bin/env ruby
# Genera una card social per-post (#131) da scripts/og_post_card.html.
#
#   ruby scripts/generate_og_cards.rb
#     env LIMIT=5      genera al massimo N card (per provare)
#     env FORCE=1      rigenera anche quelle già presenti
#     env DRY_RUN=1    elenca cosa farebbe
#     env QUALITY=82   qualità JPEG (default 82)
#
# Le card finiscono in assets/images/og/<slug>.jpg e si committano.
# JPEG e non PNG: a 1200x630 lo screenshot PNG pesa ~120 KB, il JPEG ~45 KB, e
# per 200 post la differenza è ~15 MB di repo. Le anteprime social sono foto,
# nessuno ci guarda gli artefatti.
#
# QUALI POST: solo quelli che altrimenti resterebbero senza anteprima propria,
# cioè `image:` vuota E nessuna facade <lite-youtube> (per quelli
# `_plugins/youtube_thumbnails.rb` mette già la thumbnail del video).
#
# A servirle è `_plugins/og_image.rb`, che usa la card solo se il file esiste:
# senza, si ricade sulla card generica. Quindi non lanciare questo script non
# rompe niente.
#
# Serve Chrome. Per PNG -> JPEG usa `sips` (macOS) o ImageMagick.
#
# Stdlib only.

require 'fileutils'
require 'yaml'
require 'date'
require 'uri'

ROOT = File.expand_path('..', __dir__)
TEMPLATE = File.join(ROOT, 'scripts', 'og_post_card.html')
OUT_DIR = File.join(ROOT, 'assets', 'images', 'og')
LIMIT = ENV['LIMIT'].to_s.empty? ? nil : Integer(ENV['LIMIT'])
FORCE = !ENV['FORCE'].to_s.empty?
DRY_RUN = !ENV['DRY_RUN'].to_s.empty?
QUALITY = Integer(ENV.fetch('QUALITY', '82'))

CHROME_CANDIDATES = [
  ENV['CHROME_PATH'],
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  'google-chrome',
  'chromium'
].compact

def chrome_binary
  CHROME_CANDIDATES.find do |c|
    File.executable?(c) || system('command', '-v', c, out: File::NULL, err: File::NULL)
  end
end

def tool?(name)
  system('command', '-v', name, out: File::NULL, err: File::NULL)
end

# Nome file del post senza estensione, DATA INCLUSA. Non lo slug del permalink:
# tre coppie di post condividono lo stesso slug (`allan-nava-padel-murat4ll`,
# …) e si spartirebbero una card sola, con la data — e potenzialmente il titolo
# — di quello generato per primo. Il nome file invece è unico per costruzione.
def card_name(path)
  File.basename(path).sub(/\.\w+\z/, '')
end

def front_matter(src)
  return nil unless src.start_with?('---')

  raw = src.split(/^---\s*$/)[1]
  return nil unless raw

  YAML.safe_load(raw, permitted_classes: [Date, Time]) || {}
rescue StandardError
  nil
end

def needs_card?(data, body)
  return false unless data

  image = data['image'].to_s.strip
  return false unless image.empty?

  # I post video prendono la thumbnail da youtube_thumbnails.rb.
  !body.include?('<lite-youtube')
end

# Kicker e meta della card: categoria e data, con i tag se ci stanno.
def card_fields(data, path)
  category = data['category'].to_s.strip
  kicker = category == 'project' ? 'Allan Nava — project' : 'Allan Nava — blog'

  date = data['date']
  date_str = begin
    (date.respond_to?(:strftime) ? date : Date.parse(date.to_s)).strftime('%d %b %Y')
  rescue StandardError
    File.basename(path)[0, 10]
  end

  tags = Array(data['tag']).compact.map(&:to_s).reject(&:empty?).first(3)
  meta = [date_str, tags.join(' · ')].reject(&:empty?).join('  ·  ')
  [kicker, meta]
end

def shoot(chrome, url, output)
  system(
    chrome, '--headless=new', '--disable-gpu', '--hide-scrollbars',
    '--allow-file-access-from-files', '--force-device-scale-factor=1',
    '--window-size=1200,630', '--virtual-time-budget=4000',
    "--screenshot=#{output}", url,
    out: File::NULL, err: File::NULL
  ) && File.exist?(output)
end

def to_jpeg(png, jpg)
  if tool?('sips')
    system('sips', '-s', 'format', 'jpeg', '-s', 'formatOptions', QUALITY.to_s,
           png, '--out', jpg, out: File::NULL, err: File::NULL)
  elsif tool?('magick')
    system('magick', png, '-quality', QUALITY.to_s, jpg, out: File::NULL, err: File::NULL)
  else
    false
  end
end

abort "Template mancante: #{TEMPLATE}" unless File.exist?(TEMPLATE)

chrome = chrome_binary
abort 'Chrome non trovato: esporta CHROME_PATH con il percorso del binario.' unless chrome
abort 'Serve sips o ImageMagick per convertire in JPEG.' unless tool?('sips') || tool?('magick')

FileUtils.mkdir_p(OUT_DIR)

todo = []
Dir[File.join(ROOT, '_posts', '*')].sort.each do |path|
  src = File.read(path, encoding: 'UTF-8')
  data = front_matter(src)
  body = src.split(/^---\s*$/)[2].to_s
  next unless needs_card?(data, body)

  slug = card_name(path)
  out = File.join(OUT_DIR, "#{slug}.jpg")
  next if File.exist?(out) && !FORCE

  todo << [path, data, slug, out]
end

total = todo.size
todo = todo.first(LIMIT) if LIMIT

if DRY_RUN
  todo.each { |(_, d, slug, _)| puts format('  %-58s %s', "#{slug}.jpg", d['title']) }
  puts "#{todo.size} card da generare#{LIMIT ? " (di #{total})" : ''} (dry run)."
  exit 0
end

made = 0
bytes = 0
tmp_png = File.join(OUT_DIR, '.tmp-card.png')

todo.each_with_index do |(path, data, slug, out), i|
  kicker, meta = card_fields(data, path)
  query = URI.encode_www_form(
    'title' => data['title'].to_s,
    'kicker' => kicker,
    'meta' => meta
  )

  unless shoot(chrome, "file://#{TEMPLATE}?#{query}", tmp_png)
    warn "  ! screenshot fallito: #{slug}"
    next
  end

  unless to_jpeg(tmp_png, out)
    warn "  ! conversione JPEG fallita: #{slug}"
    next
  end

  made += 1
  bytes += File.size(out)
  puts format('  [%3d/%3d] %-52s %4d KB', i + 1, todo.size, "#{slug}.jpg", File.size(out) / 1024)
end

FileUtils.rm_f(tmp_png)

puts
puts "#{made} card generate#{LIMIT ? " (restano #{total - made})" : ''}."
puts format('peso totale: %.1f MB · media %d KB', bytes / 1024.0 / 1024, made.positive? ? bytes / made / 1024 : 0)
