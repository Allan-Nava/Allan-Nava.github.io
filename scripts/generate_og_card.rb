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
  # Runner Linux: i pacchetti mettono il binario in /usr/bin, e senza questi
  # percorsi la ricerca dipendeva solo dal PATH.
  '/usr/bin/google-chrome',
  '/usr/bin/google-chrome-stable',
  '/usr/bin/chromium',
  '/usr/bin/chromium-browser',
  'google-chrome',
  'google-chrome-stable',
  'chromium',
  'chromium-browser'
].compact

# Ricerca di un eseguibile nel PATH, in Ruby puro.
#
# NON usare `system('command', '-v', nome)`: `command` è un builtin di shell e
# su Ubuntu **non esiste** come binario, quindi la forma ad array fallisce
# sempre. Su macOS invece /usr/bin/command esiste davvero, per cui il bug non si
# vedeva in locale — è così che il workflow Image Optimize è morto in CI con
# "Chrome non trovato" pur avendo Chrome installato.
def which(name)
  return name if name.include?(File::SEPARATOR) && File.executable?(name)

  ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).each do |dir|
    candidate = File.join(dir, name)
    return candidate if File.file?(candidate) && File.executable?(candidate)
  end
  nil
end

def tool?(name)
  !which(name).nil?
end

def chrome_binary
  # `map.compact.first` e non `filter_map`: quest'ultimo richiede Ruby 2.7,
  # e questi script devono girare anche col Ruby di sistema di macOS (2.6).
  CHROME_CANDIDATES.map { |c| which(c) }.compact.first
end

abort "Template mancante: #{TEMPLATE}" unless File.exist?(TEMPLATE)

chrome = chrome_binary
unless chrome
  abort "Chrome non trovato. Cercati (in ordine):\n  " +
        CHROME_CANDIDATES.join("\n  ") +
        "\nPATH=#{ENV.fetch('PATH', '')}\nEsporta CHROME_PATH col percorso del binario."
end

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
