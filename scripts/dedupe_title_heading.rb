#!/usr/bin/env ruby
# One-shot: toglie dal corpo dei post il primo heading quando ripete il titolo
# già stampato nell'<h1> dall'header (#153).
#
# Usage: ruby scripts/dedupe_title_heading.rb
#   env DRY_RUN=1  — elenca cosa cambierebbe senza scrivere niente
#
# Eredità del tema originale, dove l'header il titolo non lo stampava: aprendo
# un post lo si leggeva due volte di fila. I generatori (sync_youtube.rb,
# backfill_youtube.rb, sync_github.rb, sync_strava.rb) lo replicavano; sono
# stati corretti insieme a questo script, quindi i post nuovi nascono puliti.
#
# Cosa tocca — solo il **primo** blocco non vuoto del corpo, solo se è un
# heading, e solo se il testo coincide col titolo secondo uno di due criteri:
#
#   exact  spazi normalizzati e case ignorato
#   emoji  anche a meno di emoji, shortcode :nome: e punteggiatura di bordo
#          ("Realismo Magico" vs "## 🎨 Realismo Magico")
#
# Tutto il resto resta dov'è: un post il cui primo heading dice un'altra cosa
# ("Narciso e Boccadoro" vs "## Le tre vite di Boccadoro") non viene toccato,
# e nemmeno gli heading più in basso nel corpo.
#
# Idempotente: rigirarlo non trova più nulla da fare.
# Stdlib only, niente bundle install.

require 'yaml'
require 'date'

ROOT = File.expand_path('..', __dir__)
DRY_RUN = !ENV['DRY_RUN'].to_s.empty?

# Il primo heading del corpo, con quello che lo segue fino al testo vero.
HEADING = /\A(\#{1,6})[ \t]*(.+?)[ \t]*\r?\n(?:[ \t]*\r?\n)*/

# Le emoji che compaiono davvero nei titoli: pittogrammi, simboli, bandiere,
# frecce e il variation selector che le accompagna.
EMOJI = /[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{2190}-\u{21FF}\u{200D}]/

def normalize(text)
  text.to_s.gsub(/\s+/, ' ').strip.downcase
end

# Confronto "a meno di decorazioni": via gli shortcode di jemoji, via le emoji
# unicode, via la punteggiatura ai bordi. Serve per gli 8 post dove l'heading è
# lo stesso titolo con un'emoji davanti o una in più in coda.
def undecorate(text)
  normalize(text)
    .gsub(/:[a-z0-9_+-]+:/, ' ')
    .gsub(EMOJI, ' ')
    .gsub(/\s+/, ' ')
    .gsub(/\A[[:punct:]\s]+|[[:punct:]\s]+\z/, '')
    .strip
end

def front_matter(raw)
  return nil unless raw.start_with?('---')

  parts = raw.split(/^---\s*$/, 3)
  return nil if parts.size < 3

  data = begin
    YAML.safe_load(parts[1], permitted_classes: [Date, Time], aliases: true)
  rescue StandardError
    nil
  end
  return nil unless data.is_a?(Hash)

  [data, parts[1], parts[2]]
end

counts = Hash.new(0)
skipped = []

Dir[File.join(ROOT, '_posts', '*')].sort.each do |path|
  next if File.directory?(path)

  raw = File.read(path, encoding: 'UTF-8')
  parsed = front_matter(raw)
  unless parsed
    counts[:unparsed] += 1
    next
  end

  data, fm, body = parsed
  title = data['title'].to_s
  next if title.empty?

  # `lstrip` sul corpo: fra `---` e il primo heading c'è sempre una riga vuota.
  # Le newline iniziali si rimettono a mano dopo il taglio, così il file resta
  # nella forma canonica `---\n\n<corpo>`.
  stripped = body.lstrip
  m = stripped.match(HEADING)
  next unless m

  heading = m[2]
  kind =
    if normalize(heading) == normalize(title) then :exact
    elsif !undecorate(heading).empty? && undecorate(heading) == undecorate(title) then :emoji
    end
  next unless kind

  rest = stripped[m.end(0)..].to_s
  if rest.strip.empty?
    # Togliere l'heading lascerebbe un post senza corpo: meglio un titolo
    # ripetuto che una pagina vuota. Sono da riscrivere a mano.
    skipped << File.basename(path)
    next
  end

  counts[kind] += 1

  if DRY_RUN
    puts "#{File.basename(path)}  [#{kind}]"
    puts "    titolo:  #{title}"
    puts "    rimuove: #{m[1]} #{heading}"
    next
  end

  File.write(path, "---#{fm}---\n\n#{rest}")
end

total = counts[:exact] + counts[:emoji]
puts
puts "#{total} post ripuliti#{' (dry run)' if DRY_RUN} — #{counts[:exact]} identici, #{counts[:emoji]} a meno di emoji."
puts "#{counts[:unparsed]} file senza front matter leggibile, saltati." if counts[:unparsed].positive?

if skipped.any?
  puts
  puts "Saltati perché il corpo è solo il titolo (#{skipped.size}), da riscrivere a mano:"
  skipped.each { |name| puts "  - #{name}" }
end
