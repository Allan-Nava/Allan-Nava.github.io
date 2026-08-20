#!/usr/bin/env ruby
# One-shot (#148): unifica le varianti di uno stesso tag.
#
# `iOS` e `ios`, `open source` e `open-source`, `github actions` e
# `github-actions` sono lo stesso argomento, ma per Jekyll sono tag diversi:
# generano due voci nella cloud, due conteggi e due archivi, ognuno con meta'
# dei post. La pagina /tags li mostrava affiancati come se fossero temi distinti.
#
# Canonica: la variante gia' uguale al proprio slug (`github-actions`), se c'e';
# altrimenti la piu' usata. Deterministico, quindi rilanciarlo non cambia idea.
#
# Usage: ruby scripts/consolidate_tags.rb
#   env DRY_RUN=1  — mostra cosa cambierebbe senza scrivere
#
# Stdlib only.

require 'yaml'
require 'date'

ROOT = File.expand_path('..', __dir__)
DRY_RUN = !ENV['DRY_RUN'].to_s.empty?

def slugify(tag)
  tag.to_s.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-|-\z/, '')
end

posts = Dir[File.join(ROOT, '_posts', '*.markdown')].sort
usage = Hash.new { |h, k| h[k] = [] }

posts.each do |path|
  front = File.read(path, encoding: 'UTF-8')[/\A---\n(.*?)\n---/m, 1]
  next unless front

  data = begin
    YAML.safe_load(front, permitted_classes: [Date, Time])
  rescue StandardError
    nil
  end
  next unless data

  Array(data['tag']).each { |tag| usage[tag.to_s] << path }
end

groups = usage.keys.group_by { |tag| slugify(tag) }.select { |_, variants| variants.size > 1 }
if groups.empty?
  puts 'Nessuna variante da unificare.'
  exit 0
end

canonical = {}
groups.each do |slug, variants|
  winner = variants.find { |v| v == slug } || variants.max_by { |v| usage[v].size }
  variants.each { |v| canonical[v] = winner unless v == winner }
  puts "#{slug}: #{variants.map { |v| "#{v.inspect} (#{usage[v].size})" }.join(' + ')} -> #{winner.inspect}"
end

touched = 0
posts.each do |path|
  src = File.read(path, encoding: 'UTF-8')
  front = src[/\A---\n(.*?)\n---/m, 1]
  next unless front

  new_front = front.dup
  canonical.each do |from, to|
    # Solo le voci della lista `tag:`, ancorate al trattino: cosi' non si tocca
    # una parola uguale finita in title o description.
    new_front = new_front.gsub(/^(\s*-\s*)#{Regexp.escape(from)}\s*$/) { "#{Regexp.last_match(1)}#{to}" }
  end
  next if new_front == front

  # Un post che aveva entrambe le varianti si ritroverebbe il tag doppio.
  lines = new_front.lines
  seen = {}
  deduped = lines.reject do |line|
    m = line.match(/^\s*-\s*(.+?)\s*$/)
    next false unless m && canonical.values.include?(m[1])

    key = m[1]
    was = seen[key]
    seen[key] = true
    was
  end
  new_front = deduped.join

  File.write(path, src.sub(front, new_front)) unless DRY_RUN
  touched += 1
end

puts
puts "#{touched} post #{DRY_RUN ? 'da aggiornare (dry run)' : 'aggiornati'}."
