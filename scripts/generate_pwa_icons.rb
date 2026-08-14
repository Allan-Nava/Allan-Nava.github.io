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
  'google-chrome',
  'chromium'
].compact

def chrome_binary
  CHROME_CANDIDATES.find do |candidate|
    File.executable?(candidate) || system('command', '-v', candidate, out: File::NULL, err: File::NULL)
  end
end

def tool?(name)
  system('command', '-v', name, out: File::NULL, err: File::NULL)
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
abort 'Chrome non trovato: esporta CHROME_PATH con il percorso del binario.' unless chrome

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
