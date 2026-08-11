#!/usr/bin/env ruby
# Rigenera la card social (og:image) a partire da scripts/og_card.html.
#
#   ruby scripts/generate_og_card.rb
#
# L'immagine finisce in assets/images/og-default.png ed è quella che
# _layouts/default.html usa come og:image per le pagine e i post senza `image:`
# (senza, quei link condivisi arrivano senza anteprima).
#
# Serve Chrome: si fa uno screenshot 1200x630 del template locale. È un passo
# manuale di proposito — la card cambia una volta ogni tanto, e committare il
# PNG evita di dover installare un renderer in CI.
#
# Stdlib only.

require 'fileutils'

ROOT = File.expand_path('..', __dir__)
TEMPLATE = File.join(ROOT, 'scripts', 'og_card.html')
OUTPUT = File.join(ROOT, 'assets', 'images', 'og-default.png')

CHROME_CANDIDATES = [
  ENV['CHROME_PATH'],
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  'google-chrome',
  'chromium'
].compact

def chrome_binary
  CHROME_CANDIDATES.find do |candidate|
    File.executable?(candidate) || system('command', '-v', candidate, out: File::NULL, err: File::NULL)
  end
end

abort "Template mancante: #{TEMPLATE}" unless File.exist?(TEMPLATE)

chrome = chrome_binary
abort 'Chrome non trovato: esporta CHROME_PATH con il percorso del binario.' unless chrome

FileUtils.mkdir_p(File.dirname(OUTPUT))

# --allow-file-access-from-files serve al @font-face del template, che carica
# il woff2 self-hosted da file://.
ok = system(
  chrome,
  '--headless=new',
  '--disable-gpu',
  '--hide-scrollbars',
  '--allow-file-access-from-files',
  '--force-device-scale-factor=1',
  '--window-size=1200,630',
  '--virtual-time-budget=4000',
  "--screenshot=#{OUTPUT}",
  "file://#{TEMPLATE}",
  out: File::NULL, err: File::NULL
)

abort 'Chrome ha fallito lo screenshot.' unless ok && File.exist?(OUTPUT)

size_kb = (File.size(OUTPUT) / 1024.0).round
puts "og-default.png rigenerata (#{size_kb} KB) → #{OUTPUT.sub(ROOT + '/', '')}"
