# frozen_string_literal: true
#
# Raggruppa le foto consecutive di un post in una galleria (#154).
#
# I post fotografici scrivono un'immagine per <div>, uno sotto l'altro:
#
#   <div><picture>…</picture></div>
#   <div><picture>…</picture></div>
#
# che il CSS impagina a piena larghezza, una per schermata. Il post del
# matrimonio sono 6 scatti quasi identici e ~4000px di scroll. Qui una sequenza
# di due o più diventa:
#
#   <div class="gallery" data-photos="6"> …i div originali… </div>
#
# e `_sass/components/gallery.sass` la dispone in griglia. I <div> interni non
# vengono toccati: restano quelli, con dentro il <picture> che ha già le
# varianti WebP/AVIF — quindi la griglia serve i tagli piccoli ed è più
# leggera della colonna a piena larghezza, non più pesante.
#
# 22 post hanno almeno due immagini consecutive, per 77 foto in tutto.
#
# L'attributo è `data-photos` e NON `data-count`: quest'ultimo è già usato dai
# numeri animati della home, e il loro script selezionava `[data-count]` senza
# altri vincoli — svuotava la galleria e ci scriveva dentro la cifra.
#
# ORDINE: gira sia prima sia dopo `responsive_images.rb` (l'ordine di
# caricamento è alfabetico e questo file viene prima), quindi il blocco è
# riconosciuto in entrambe le forme — con il <picture> e senza. Raggruppa i
# <div>, che in nessuno dei due casi cambiano.
module PhotoGallery
  # Un "blocco foto": un <div> che contiene solo un'immagine, in una delle due
  # forme, e nient'altro oltre agli spazi.
  BLOCK = %r{<div>\s*(?:<picture>.*?</picture>|<img\b[^>]*>)\s*</div>}m
  CONTENT = %r{(<div class="post-content">)(.*?)(</div>\s*</article>)}m
  MIN_PHOTOS = 2

  class << self
    def process(html)
      # Idempotenza: l'hook è registrato su [:posts, :pages, :documents] e per un
      # post scatta due volte. Se la galleria c'è già, il documento è fatto.
      return html if html.include?('class="gallery"')
      return html unless html.include?('<div class="post-content">')

      html.sub(CONTENT) { "#{Regexp.last_match(1)}#{group(Regexp.last_match(2))}#{Regexp.last_match(3)}" }
    end

    private

    # Raccoglie le corse di blocchi separati solo da spazi e avvolge quelle
    # lunghe almeno MIN_PHOTOS.
    def group(content)
      out = +''
      cursor = 0
      run = []

      content.to_enum(:scan, BLOCK).each do
        m = Regexp.last_match
        gap = content[cursor...m.begin(0)]

        if run.any? && gap.strip.empty?
          run << m[0]
        else
          out << flush(run) << gap
          run = [m[0]]
        end
        cursor = m.end(0)
      end

      out << flush(run) << content[cursor..].to_s
      out
    end

    def flush(run)
      return '' if run.empty?
      return run.join if run.size < MIN_PHOTOS

      %(<div class="gallery" data-photos="#{run.size}">#{run.join}</div>)
    end
  end
end

Jekyll::Hooks.register [:posts, :pages, :documents], :post_render do |doc|
  next unless doc.output_ext == '.html'

  doc.output = PhotoGallery.process(doc.output)
end
