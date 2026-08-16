# frozen_string_literal: true
#
# Anteprima social corretta per ogni post (#131). Fa due cose distinte.
#
# 1. TOGLIE `image: ""` DAI DATI DEL POST.
#    315 post su 335 hanno `image: ""` nel front matter. Una stringa vuota per
#    jekyll-seo-tag è **truthy**: la risolve come URL relativo e sputa
#    `<meta property="og:image" content="https://allan-nava.github.io/">`, cioè
#    l'URL del sito al posto di un'immagine. Quelle pagine finivano con DUE
#    og:image — prima quella rotta del seo tag, poi quella buona di
#    default.html — e gli scraper leggono la prima. Risultato: 201 post
#    progetto si condividevano con l'anteprima rotta.
#    Cancellare la chiave è sufficiente e non cambia nient'altro: tutti i
#    template la testano già come `post.image and post.image != ""`.
#
# 2. ASSEGNA LA CARD PER-POST, se esiste su disco.
#    Le genera `scripts/generate_og_cards.rb` in assets/images/og/<slug>.jpg e
#    sono committate. Il valore finisce in `page.og_card`, NON in `page.image`:
#    `image` è anche la thumbnail dei listing, e riempirla con una card 1200x630
#    sostituirebbe i placeholder generativi di /blog, /projects e home con
#    l'anteprima social, scaricando 54 KB per riga di elenco.
#    Se il file non c'è, `default.html` ricade sulla card generica: non lanciare
#    il generatore non rompe niente.
#
# Generator con priorità :lowest per girare DOPO youtube_thumbnails.rb
# (priorità :low), che riempie `image` dei post video con la thumbnail YouTube:
# quelli hanno già un'anteprima loro e non devono ricevere una card.
module Jekyll
  class OgImage < Generator
    safe true
    priority :lowest

    CARD_DIR = File.join('assets', 'images', 'og')

    def generate(site)
      carded = 0
      cleaned = 0

      site.posts.docs.each do |post|
        next unless post.data['image'].to_s.strip.empty?

        post.data.delete('image')
        cleaned += 1

        slug = card_name(post)
        next if slug.empty?

        relative = File.join(CARD_DIR, "#{slug}.jpg")
        next unless File.exist?(File.join(site.source, relative))

        post.data['og_card'] = "/#{relative}"
        carded += 1
      end

      Jekyll.logger.info 'OG images:',
                         "#{cleaned} post senza immagine (og:image vuoto rimosso), #{carded} con card dedicata"
    end

    private

    # Nome file del post senza estensione, come scripts/generate_og_cards.rb.
    # Con la data davanti: lo slug del permalink non è unico (tre coppie di post
    # lo condividono) e due post finirebbero sulla stessa card.
    def card_name(post)
      File.basename(post.relative_path.to_s).sub(/\.\w+\z/, '')
    end
  end
end
