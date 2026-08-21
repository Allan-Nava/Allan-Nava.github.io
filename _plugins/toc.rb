# Indice dei contenuti dei post, generato a build time.
#
# _layouts/post.html emette `<div class="toc-slot"></div>`: qui lo sostituiamo
# con un <details> che elenca gli h2/h3 del corpo del post, o lo rimuoviamo se i
# titoli sono meno di MIN_HEADINGS (post corti, video, progetti sincronizzati).
#
# Niente Nokogiri di proposito: kramdown genera già gli `id` sui titoli
# (auto_ids attivo di default), quindi basta leggerli dall'output — nessuna
# dipendenza extra che debba essere installata anche in CI.
#
# `<details open>`: aperto di default, richiudibile a mano, zero JavaScript.
module TableOfContents
  SLOT = '<div class="toc-slot"></div>'.freeze
  MIN_HEADINGS = 3
  # Solo i titoli dentro il corpo del post: fuori ci sono related, author, footer.
  CONTENT = /<div class="post-content">(.*)<\/div>/m.freeze
  HEADING = /<h([23])[^>]*\sid="([^"]+)"[^>]*>(.*?)<\/h\1>/m.freeze

  # Ancora copiabile accanto a ogni titolo del corpo (#158).
  #
  # Su un blog tecnico serve a mandare a qualcuno *quel* passaggio invece
  # dell'intero articolo. E' un `<a href="#id">` normale: senza JavaScript resta
  # un link che si copia col tasto destro; con JS, `interactions.html` ci mette
  # sopra la copia negli appunti.
  #
  # L'iniezione va resa **idempotente**: registrando su :documents un post passa
  # da qui due volte (e' sia :post sia :document), e senza il controllo si
  # otterrebbero due ancore per titolo.
  ANCHORED = 'heading-anchor'
  # L'ancora va tolta dal testo prima di usarlo come etichetta dell'indice:
  # l'hook aggiunge le ancore *prima* di costruirlo, e senza questo ogni voce
  # finiva con un "#" attaccato ("Primo#").
  ANCHOR_TAG = /<a class="#{ANCHORED}".*?<\/a>/m.freeze

  def self.add_anchors(output)
    body = output[CONTENT, 1]
    return output if body.nil? || body.include?(ANCHORED)

    anchored = body.gsub(/<h([23])([^>]*\sid="([^"]+)"[^>]*)>(.*?)<\/h\1>/m) do
      level = Regexp.last_match(1)
      attrs = Regexp.last_match(2)
      id = Regexp.last_match(3)
      inner = Regexp.last_match(4)

      link = %(<a class="#{ANCHORED}" href="##{id}" aria-label="Link to this section">#</a>)
      %(<h#{level}#{attrs}>#{inner}#{link}</h#{level}>)
    end

    output.sub(body, anchored)
  end

  def self.render(output)
    body = output[CONTENT, 1]
    return '' if body.nil?

    headings = body.scan(HEADING)
    return '' if headings.size < MIN_HEADINGS

    items = headings.map do |level, id, raw|
      text = raw.gsub(ANCHOR_TAG, '').gsub(/<[^>]+>/, '').strip
      next if text.empty?

      %(<li class="level-#{level}"><a href="##{id}">#{text}</a></li>)
    end.compact

    return '' if items.size < MIN_HEADINGS

    <<~HTML.gsub(/\n\s*/, '')
      <details class="toc" open>
        <summary class="toc-title">Contents</summary>
        <ol class="toc-list">#{items.join}</ol>
      </details>
    HTML
  end
end

Jekyll::Hooks.register :documents, :post_render do |doc|
  next unless doc.output.is_a?(String)

  # Le ancore valgono per ogni post con dei titoli, anche quelli troppo corti
  # per avere l'indice.
  doc.output = TableOfContents.add_anchors(doc.output)

  next unless doc.output.include?(TableOfContents::SLOT)

  doc.output = doc.output.sub(TableOfContents::SLOT, TableOfContents.render(doc.output))
end
