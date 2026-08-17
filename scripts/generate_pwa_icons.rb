#!/usr/bin/env ruby
# Rigenera le icone della PWA (#139) da scripts/pwa_icon.html.
#
#   ruby scripts/generate_pwa_icons.rb
#
# Produce in assets/images/pwa/:
#   icon-512.png            icona normale
#   icon-192.png            la stessa, ridotta
#   icon-maskable-512.png   composizione con margine per la maschera Android
#   icon-maskable-192.png
#
# Le dichiara `manifest.webmanifest`. Come per la card OG è un passo **manuale**
# che committa i PNG: le icone cambiano una volta ogni mai, e così non serve un
# renderer in CI.
#
# Serve Chrome per lo screenshot. Per ridurre 512 -> 192 usa `sips` (macOS) o
# ImageMagick se c'è; senza nessuno dei due genera solo i 512 e lo dice.
#
# Stdlib only.

require 'fileutils'

ROOT = File.expand_path('..', __dir__)
TEMPLATE = File.join(ROOT, 'scripts', 'pwa_icon.html')
OUT_DIR = File.join(ROOT, 'assets', 'images', 'pwa')

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

def chrome_binary
  # `map.compact.first` e non `filter_map`: quest'ultimo richiede Ruby 2.7,
  # e questi script devono girare anche col Ruby di sistema di macOS (2.6).
  CHROME_CANDIDATES.map { |c| which(c) }.compact.first
end

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

def shoot(chrome, url, output)
  ok = system(
    chrome,
    '--headless=new',
    '--disable-gpu',
    '--hide-scrollbars',
    '--allow-file-access-from-files',
    '--force-device-scale-factor=1',
    '--window-size=512,512',
    '--virtual-time-budget=4000',
    "--screenshot=#{output}",
    url,
    out: File::NULL, err: File::NULL
  )
  abort "Chrome ha fallito lo screenshot di #{File.basename(output)}." unless ok && File.exist?(output)
end

def resize(src, dst, size)
  if tool?('sips')
    system('sips', '-z', size.to_s, size.to_s, src, '--out', dst, out: File::NULL, err: File::NULL)
  elsif tool?('magick')
    system('magick', src, '-resize', "#{size}x#{size}", dst, out: File::NULL, err: File::NULL)
  else
    false
  end
end

abort "Template mancante: #{TEMPLATE}" unless File.exist?(TEMPLATE)

chrome = chrome_binary
unless chrome
  abort "Chrome non trovato. Cercati (in ordine):\n  " +
        CHROME_CANDIDATES.join("\n  ") +
        "\nPATH=#{ENV.fetch('PATH', '')}\nEsporta CHROME_PATH col percorso del binario."
end

FileUtils.mkdir_p(OUT_DIR)

made = []
[['icon', ''], ['icon-maskable', '?maskable=1']].each do |name, query|
  big = File.join(OUT_DIR, "#{name}-512.png")
  shoot(chrome, "file://#{TEMPLATE}#{query}", big)
  made << big

  small = File.join(OUT_DIR, "#{name}-192.png")
  if resize(big, small, 192)
    made << small
  else
    warn "  ! nessun ridimensionatore (sips/magick): #{File.basename(small)} non generata"
  end
end

made.each do |f|
  puts format('  %-34s %5d KB', f.sub("#{ROOT}/", ''), File.size(f) / 1024)
end
puts "#{made.size} icone generate."
