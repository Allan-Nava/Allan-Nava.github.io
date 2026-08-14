#!/usr/bin/env ruby
# Genera le varianti moderne e responsive delle immagini in assets/images (#138).
#
# Per ogni JPEG/PNG sopra soglia produce, accanto all'originale:
#   nome-<w>.webp      una per ogni breakpoint più piccolo della nativa
#   nome.webp          solo se l'originale è già più stretto del breakpoint massimo
#
# ATTENZIONE, AVIF: il ramo `avifenc` esiste ma **non è mai stato eseguito** —
# l'encoder non era disponibile in fase di sviluppo e il workflow
# image-optimize.yml non lo installa. Inoltre avifenc non ridimensiona, quindi
# oggi produrrebbe AVIF solo alle larghezze native, cioè quasi mai. Il plugin
# `_plugins/responsive_images.rb` è già pronto a servirli quando i file
# esisteranno: prima di fidarsi, va provato su qualche immagine vera.
#
# L'originale NON viene toccato: resta il fallback dentro <picture>, che è quello
# che `_plugins/responsive_images.rb` costruisce a build time leggendo quali
# varianti esistono davvero su disco. Quindi questo script e il plugin sono
# indipendenti: se le varianti non ci sono, il sito serve l'originale e basta.
#
# Perché generare qui e committare, invece di convertire durante il build:
# il build di Pages gira con il bundle `github-pages`, che non ha né encoder né
# librerie native per le immagini. Stessa scelta già fatta per la card OG
# (`scripts/generate_og_card.rb`).
#
# Uso: ruby scripts/optimize_images.rb
#   env THRESHOLD_KB  — ignora i file più leggeri di così (default 150)
#   env QUALITY       — qualità webp/avif (default 82)
#   env WIDTHS        — breakpoint, separati da virgola (default 480,960,1440).
#                       Misurati, non dedotti: il browser non mira alla larghezza
#                       CSS dello slot (~700px) ma a slot × DPR, quindi su mobile
#                       chiede ~950-1080px. Provato a sostituire 960 con 720
#                       pensando di risparmiare: il browser salta a 1440 e la
#                       pagina passa da 0.9 a 1.3 MB. Il tier medio serve, e va
#                       lasciato sopra i 900.
#   env DRY_RUN=1     — dice cosa farebbe senza scrivere niente
#   env FORCE=1       — rigenera anche le varianti già aggiornate
#
# Stdlib only: gli encoder sono binari esterni (cwebp, avifenc), non gem.

require 'fileutils'
require 'shellwords'

ROOT = File.expand_path('..', __dir__)
IMAGES = File.join(ROOT, 'assets', 'images')
THRESHOLD = Integer(ENV.fetch('THRESHOLD_KB', '150')) * 1024
QUALITY = Integer(ENV.fetch('QUALITY', '82'))
WIDTHS = ENV.fetch('WIDTHS', '480,960,1440').split(',').map { |w| Integer(w.strip) }.sort
DRY_RUN = !ENV['DRY_RUN'].to_s.empty?
FORCE = !ENV['FORCE'].to_s.empty?

# I GIF restano fuori: `error.gif` ha 50 frame e cwebp produce solo webp
# statiche, quindi convertirlo significherebbe perdere l'animazione.
SOURCE_EXT = %w[.jpg .jpeg .png].freeze

def tool?(name)
  system("command -v #{Shellwords.escape(name)} > /dev/null 2>&1")
end

HAVE_WEBP = tool?('cwebp')
HAVE_AVIF = tool?('avifenc')

# --- dimensioni senza dipendenze --------------------------------------------
# Serve solo la larghezza, per non generare varianti più grandi dell'originale
# (upscalare peggiora il peso senza aggiungere un pixel di dettaglio).

def png_width(io)
  io.seek(16)
  io.read(4).unpack1('N')
end

def jpeg_width(io)
  io.seek(2)
  while (marker = io.read(2))
    break unless marker.getbyte(0) == 0xFF

    code = marker.getbyte(1)
    # SOF0..SOF15 tranne DHT/JPG/DAC: qui stanno le dimensioni
    if (0xC0..0xCF).cover?(code) && ![0xC4, 0xC8, 0xCC].include?(code)
      io.read(3) # length + precision
      io.read(2) # height
      return io.read(2).unpack1('n')
    end

    length = io.read(2).to_s.unpack1('n')
    break unless length && length >= 2

    io.seek(length - 2, IO::SEEK_CUR)
  end
  nil
end

def image_width(path)
  File.open(path, 'rb') do |io|
    sig = io.read(8)
    io.rewind
    if sig&.start_with?("\x89PNG".b)
      png_width(io)
    elsif sig && sig.getbyte(0) == 0xFF && sig.getbyte(1) == 0xD8
      jpeg_width(io)
    end
  end
rescue StandardError => e
  warn "  ! dimensioni non leggibili (#{File.basename(path)}): #{e.message}"
  nil
end

# --- encoder ----------------------------------------------------------------

def run(cmd)
  return true if DRY_RUN

  ok = system(*cmd, out: File::NULL, err: File::NULL)
  warn "  ! encoder fallito: #{cmd.first}" unless ok
  ok
end

def encode_webp(src, dst, width)
  cmd = ['cwebp', '-quiet', '-q', QUALITY.to_s]
  cmd += ['-resize', width.to_s, '0'] if width
  cmd += [src, '-o', dst]
  run(cmd)
end

def encode_avif(src, dst, width)
  # avifenc non ridimensiona: le varianti per larghezza le fa solo il webp.
  return false if width

  run(['avifenc', '--min', '0', '--max', '40', '-a', "end-usage=q", '-a', "cq-level=#{(100 - QUALITY) / 2}",
       src, dst])
end

def stale?(dst, src)
  FORCE || !File.exist?(dst) || File.mtime(dst) < File.mtime(src)
end

# --- giro principale --------------------------------------------------------

abort "Cartella non trovata: #{IMAGES}" unless Dir.exist?(IMAGES)

unless HAVE_WEBP || HAVE_AVIF
  abort "Nessun encoder disponibile. Installa almeno cwebp:\n" \
        "  macOS: brew install webp\n  Debian/Ubuntu: apt-get install webp"
end

puts "encoder: webp=#{HAVE_WEBP ? 'cwebp' : 'assente'} avif=#{HAVE_AVIF ? 'avifenc' : 'assente'}"
puts "soglia: #{THRESHOLD / 1024} KB · qualità: #{QUALITY} · larghezze: #{WIDTHS.join(', ')}"
puts

sources = Dir.glob(File.join(IMAGES, '**', '*')).select do |f|
  File.file?(f) && SOURCE_EXT.include?(File.extname(f).downcase)
end.sort

created = 0
skipped_small = 0
src_bytes = 0
new_bytes = 0

sources.each do |src|
  size = File.size(src)
  if size < THRESHOLD
    skipped_small += 1
    next
  end

  base = src.sub(/#{Regexp.escape(File.extname(src))}\z/, '')
  native = image_width(src)
  targets = []

  # Larghezze utili = i breakpoint più stretti della nativa (niente upscaling).
  WIDTHS.each do |w|
    next if native && w >= native

    targets << [w, "#{base}-#{w}.webp", :webp]
  end

  # La variante alla larghezza nativa si genera SOLO se l'originale è già più
  # piccolo del breakpoint massimo. Sopra, sarebbe peso morto: `sizes` in
  # `_plugins/responsive_images.rb` chiede al massimo 700px, quindi nemmeno un
  # display a DPR 2 arriverebbe a chiedere più di 1440px.
  if native.nil? || native <= WIDTHS.max
    targets << [nil, "#{base}.webp", :webp]
    targets << [nil, "#{base}.avif", :avif] if HAVE_AVIF
  end

  did = []
  targets.each do |width, dst, fmt|
    next unless stale?(dst, src)
    next if fmt == :webp && !HAVE_WEBP
    next if fmt == :avif && !HAVE_AVIF

    ok = fmt == :webp ? encode_webp(src, dst, width) : encode_avif(src, dst, width)
    next unless ok

    did << File.basename(dst)
    created += 1
    new_bytes += File.exist?(dst) ? File.size(dst) : 0
  end

  next if did.empty?

  src_bytes += size
  rel = src.sub("#{ROOT}/", '')
  puts format('%-52s %6d KB  ->  %s', rel, size / 1024, did.join(' '))
end

puts
puts "#{sources.size} sorgenti (#{skipped_small} sotto soglia, ignorate)"
if DRY_RUN
  puts "#{created} varianti da generare (dry run)."
else
  puts "#{created} varianti generate."
  if src_bytes.positive?
    puts format('originali coinvolti: %.1f MB · varianti: %.1f MB',
                src_bytes / 1024.0 / 1024, new_bytes / 1024.0 / 1024)
  end
end
