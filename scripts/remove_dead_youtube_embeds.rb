#!/usr/bin/env ruby
# frozen_string_literal: true

# One-shot (#170): toglie dai post le facade <lite-youtube> che puntano a video
# non piu' esistenti su YouTube.
#
# Perche' e' un problema e non solo un link rotto: da quei videoid
# `_plugins/youtube_thumbnails.rb` deriva la thumbnail `i.ytimg.com`, che e'
# anche l'`og:image` del post. Un video rimosso lascia quindi un player vuoto
# **e** un'anteprima social 404 — il check mensile dei link li segnalava come
# `i.ytimg.com/vi/<id>/hqdefault.jpg failed (status code 404)`.
#
# Come si riconosce un video morto: `hqdefault.jpg` risponde 404. La pagina
# `watch?v=` NON serve — YouTube restituisce 200 anche per un video inesistente,
# servendo la sua pagina di errore. Il controllo va fatto su i.ytimg.com, con un
# User-Agent da browser, e va sempre validato contro un id notoriamente vivo:
# senza quel controllo di riferimento non si distingue "video morto" da "sono
# stato bloccato", e si cancellerebbero embed buoni.
#
#   DRY_RUN=1 ruby scripts/remove_dead_youtube_embeds.rb   # mostra e non scrive
#   ruby scripts/remove_dead_youtube_embeds.rb             # applica
#
# Gli id sono passati per argomento o presi da DEAD_IDS. Lo script tocca solo i
# post che li contengono e lascia in pace ogni altro embed.

require 'fileutils'

POSTS_DIR = File.expand_path('../_posts', __dir__)

# I 17 video risultati 404 al giro del 2026-09-16, su 174 videoid nei post.
DEAD_IDS = %w[
  0B7-iEcLG8o 71EcZ0ZQejo EuYgp4Dq5LI F0pHik5TYkM O6am0_LDG10
  SzyynM9Bhgo UP-DspVsx0w YSOOtdT4igQ Yv5BMQV8-Fg Ziktpnb8p6E
  _ILi53gVKZE aMg2fm79tVo cvw3dynD0i4 klKV-DoxQG0 lgCQ88K0DEk
  lubeO-cuG6g nRXCdRX7-MQ
].freeze

dry_run = !ENV['DRY_RUN'].to_s.empty?
ids = ARGV.empty? ? DEAD_IDS : ARGV
pattern = Regexp.union(ids)

changed = 0
removed = 0
emptied = []

Dir.glob(File.join(POSTS_DIR, '*.markdown')).sort.each do |path|
  source = File.read(path)
  next unless source.match?(pattern)

  # La facade e' sempre un elemento singolo `<lite-youtube …></lite-youtube>`;
  # si porta via le righe vuote che la seguono per non lasciare buchi nel corpo.
  body = source.dup
  hits = 0
  ids.each do |id|
    # `(?:\n|\z)`: l'embed puo' essere l'ultimissima riga del file senza newline
    # finale — succede in 2026-04-12-allan-nava-trekking.markdown, e un pattern
    # che pretende `\n` lo lascia sul posto.
    body = body.gsub(/^[ \t]*<lite-youtube\b[^>]*videoid="#{Regexp.escape(id)}"[^>]*>.*?<\/lite-youtube>[ \t]*(?:\n|\z)(?:[ \t]*\n)*/m) do
      hits += 1
      ''
    end
  end
  next if hits.zero?

  # Il front matter finisce al secondo '---'; quel che resta dopo dice se il
  # post e' rimasto senza corpo.
  rest = body.split(/^---\s*$/, 3)[2].to_s
  emptied << File.basename(path) if rest.strip.empty?

  changed += 1
  removed += hits
  puts format('%-64s -%d embed%s', File.basename(path), hits, rest.strip.empty? ? '  (corpo vuoto)' : '')
  File.write(path, body) unless dry_run
end

puts
puts "#{changed} post, #{removed} embed rimossi#{dry_run ? ' (DRY RUN, nessuna scrittura)' : ''}"
unless emptied.empty?
  puts
  puts "Post rimasti senza corpo (#{emptied.size}) — hanno solo il titolo:"
  emptied.each { |f| puts "  #{f}" }
end
