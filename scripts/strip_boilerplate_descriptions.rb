#!/usr/bin/env ruby
# One-shot (#162): toglie dai post generati la `description` boilerplate.
#
# `sync_youtube.rb` scriveva "Video dal canale YouTube di Allan Nava: <titolo>",
# cioè il titolo che sta una riga sopra preceduto da una premessa uguale per
# tutti — e in italiano, mentre l'interfaccia è in inglese. Quel campo finisce
# nel <meta description>, nel summary del feed, nell'estratto di ogni card e
# nell'anteprima dei risultati di ricerca: quattro posti dove si legge due volte
# lo stesso titolo. Meglio nessuna description: i template saltano il campo
# vuoto da soli.
#
# Tocca SOLO i post generati (quelli con la facade <lite-youtube>) e solo se la
# descrizione è boilerplate, ripete il titolo o è troppo corta per dire qualcosa.
#
# Usage: ruby scripts/strip_boilerplate_descriptions.rb
#   env DRY_RUN=1  — elenca i file senza scriverli
#
# Stdlib only.

ROOT = File.expand_path('..', __dir__)
DRY_RUN = !ENV['DRY_RUN'].to_s.empty?
BOILERPLATE = /\AVideo dal canale YouTube di Allan Nava:/i.freeze
MIN_CHARS = 25

changed = []
skipped_handwritten = 0

Dir[File.join(ROOT, '_posts', '*.markdown')].sort.each do |path|
  src = File.read(path, encoding: 'UTF-8')
  front = src[/\A---\n(.*?)\n---/m, 1]
  next unless front

  # Solo i post generati dal sync YouTube.
  unless src.include?('<lite-youtube')
    skipped_handwritten += 1
    next
  end

  desc = front[/^description:\s*"(.*)"\s*$/, 1]
  next if desc.nil? || desc.empty?

  title = front[/^title:\s*"(.*)"\s*$/, 1].to_s

  reason =
    if desc =~ BOILERPLATE then 'boilerplate'
    elsif desc.strip.downcase == title.strip.downcase then 'uguale al titolo'
    elsif desc.strip.length < MIN_CHARS then 'troppo corta'
    end
  next unless reason

  new_front = front.sub(/^description:\s*".*"\s*$/, 'description: ""')
  File.write(path, src.sub(front, new_front)) unless DRY_RUN
  changed << [File.basename(path), reason, desc[0, 48]]
end

changed.each { |name, reason, desc| puts format('%-58s %-16s %s', name, reason, desc) }
puts
puts "#{changed.size} post #{DRY_RUN ? 'da ripulire (dry run)' : 'ripuliti'}; " \
     "#{skipped_handwritten} scritti a mano, non toccati."
