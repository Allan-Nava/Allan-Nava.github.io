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

  def self.render(output)
    body = output[CONTENT, 1]
    return '' if body.nil?

    headings = body.scan(HEADING)
    return '' if headings.size < MIN_HEADINGS

    items = headings.map do |level, id, raw|
      text = raw.gsub(/<[^>]+>/, '').strip
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
  next unless doc.output.include?(TableOfContents::SLOT)

  doc.output = doc.output.sub(TableOfContents::SLOT, TableOfContents.render(doc.output))
end
