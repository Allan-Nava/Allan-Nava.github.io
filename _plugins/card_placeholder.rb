# Filtri Liquid per il placeholder delle card senza thumbnail.
#
# 108 progetti sincronizzati da GitHub hanno `image: ""`: la loro card sarebbe
# solo testo. Con questi filtri il template disegna un monogramma su un
# gradiente scelto in modo deterministico dal titolo/tag — nessuna immagine da
# scaricare, nessun servizio esterno, e lo stesso progetto ha sempre lo stesso
# colore ad ogni build (l'hash è stabile, non `Object#hash`, che è randomizzato
# per processo).
module CardPlaceholder
  PALETTES = 6

  # Iniziali del titolo: "nomad-lens" -> "NL", "checkfleet" -> "CH".
  def card_initials(title)
    words = title.to_s.scan(/[[:alnum:]]+/)
    return '?' if words.empty?

    if words.size >= 2
      (words[0][0].to_s + words[1][0].to_s).upcase
    else
      words[0][0, 2].to_s.upcase
    end
  end

  # Indice di palette stabile fra build e fra macchine.
  def card_palette(seed)
    sum = seed.to_s.each_byte.reduce(0) { |acc, b| (acc * 31 + b) % 1_000_003 }
    sum % PALETTES
  end
end

Liquid::Template.register_filter(CardPlaceholder)
