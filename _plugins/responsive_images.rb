# frozen_string_literal: true
#
# Serve le varianti moderne delle immagini locali avvolgendo gli <img> di
# contenuto in un <picture> (#138).
#
#   <img class="image" src="/assets/images/foo.jpg">
#     ->
#   <picture>
#     <source type="image/avif" srcset="/assets/images/foo.avif" sizes="…">
#     <source type="image/webp" srcset="/assets/images/foo-480.webp 480w, …" sizes="…">
#     <img class="image" src="/assets/images/foo.jpg">
#   </picture>
#
# Le varianti NON vengono generate qui: le crea `scripts/optimize_images.rb` e
# stanno committate. Questo plugin guarda solo se il file esiste sul disco, e se
# non c'è lascia l'<img> esattamente com'era. Conseguenza voluta: aggiungere
# un'immagine senza lanciare lo script non rompe nulla, la si serve non
# ottimizzata; e il build non ha bisogno di encoder nativi, che nel bundle
# `github-pages` non ci sono.
#
# Gira dopo `lazy_images.rb` (ordine alfabetico di caricamento), quindi gli
# attributi loading/decoding sono già sull'<img> e vengono preservati: il tag
# originale finisce dentro <picture> senza essere riscritto.
module ResponsiveImages
  # L'alternativa con il blocco <picture> PRIMA dell'<img> è ciò che rende il
  # plugin idempotente: un'immagine già avvolta viene consumata dal primo ramo e
  # restituita intatta. Serve perché l'hook è registrato su
  # [:posts, :pages, :documents] e un post è sia :post sia :document, quindi
  # process() gira due volte sullo stesso output — senza questo si ottengono
  # <picture> annidati. (`lazy_images.rb` se la cava con un lookahead negativo.)
  IMG = %r{<picture\b.*?</picture>|<img\b[^>]*>}im
  SRC = /\bsrc=(["'])(.*?)\1/i
  # Le thumbnail delle card restano fuori: `home-blog-projects.sass` le stila con
  # selettori a figlio diretto (`> .thumb > img`), che un <picture> in mezzo
  # spezzerebbe. Sono comunque remote (i.ytimg.com), quindi non hanno varianti.
  SKIP_CLASS = /\bclass=(["'])[^"']*\bthumb[^"']*\1/i

  # Il corpo dei post è limitato a --measure (~700px); sotto i 560px l'immagine
  # prende tutta la larghezza. Sopra non serve chiedere di più.
  SIZES = '(max-width: 560px) 100vw, 700px'

  WIDTH_SUFFIX = /-(\d+)\z/.freeze

  class << self
    def process(html, source_dir)
      return html unless html.include?('/assets/images/')

      html.gsub(IMG) do |tag|
        next tag if tag.start_with?('<picture')
        next tag if tag =~ SKIP_CLASS

        m = tag.match(SRC)
        next tag unless m

        rel = local_path(m[2])
        next tag unless rel

        sources = build_sources(rel, source_dir)
        next tag if sources.empty?

        "<picture>#{sources.join}#{tag}</picture>"
      end
    end

    private

    # Accetta sia `/assets/images/x.jpg` sia l'URL assoluto del sito, che in
    # qualche post è scritto per esteso. Tutto il resto (i.ytimg.com, data:) esce.
    def local_path(src)
      path = src.sub(%r{\Ahttps?://[^/]+}, '')
      return nil unless path.start_with?('/assets/images/')
      return nil unless File.extname(path).downcase =~ /\A\.(jpe?g|png)\z/

      path
    end

    def build_sources(rel, source_dir)
      base = rel.sub(/#{Regexp.escape(File.extname(rel))}\z/, '')
      out = []

      avif = variants(base, '.avif', source_dir)
      out << source_tag(avif, 'image/avif') unless avif.empty?

      webp = variants(base, '.webp', source_dir)
      out << source_tag(webp, 'image/webp') unless webp.empty?

      out
    end

    # Ritorna [[url, larghezza_o_nil], …] per le varianti presenti su disco.
    # La variante alla larghezza nativa non ha un `w` noto: la si mette per
    # ultima senza descrittore solo se è l'unica, altrimenti servirebbe la sua
    # larghezza reale per stare in un srcset con i `w`.
    def variants(base, ext, source_dir)
      found = []
      Dir.glob(File.join(source_dir, "#{base}*#{ext}")).sort.each do |abs|
        url = abs.sub(source_dir, '')
        name = File.basename(url, ext)
        next unless name == File.basename(base) || name.start_with?("#{File.basename(base)}-")

        suffix = name.sub(File.basename(base), '')
        if suffix.empty?
          found << [url, nil]
        elsif (wm = suffix.match(WIDTH_SUFFIX))
          found << [url, wm[1].to_i]
        end
      end
      found
    end

    def source_tag(list, mime)
      sized = list.reject { |(_, w)| w.nil? }.sort_by { |(_, w)| w }
      native = list.find { |(_, w)| w.nil? }

      # Quando ci sono le varianti per larghezza si usano solo quelle: la
      # variante "nativa" non ha un `w` noto senza rileggere le dimensioni del
      # file, e inventarne uno produrrebbe scelte sbagliate del browser. Non
      # manca niente: `sizes` chiede al massimo 700px, quindi il breakpoint più
      # alto copre anche i display a DPR 2.
      unless sized.empty?
        entries = sized.map { |(url, w)| "#{url} #{w}w" }
        # `sizes` sta sul <source>, non sull'<img>: è lì che il browser decide.
        return %(<source type="#{mime}" srcset="#{entries.join(', ')}" sizes="#{SIZES}">)
      end

      # Immagini già più piccole del breakpoint minimo: una sola variante, senza
      # descrittori — non c'è niente da scegliere.
      native ? %(<source type="#{mime}" srcset="#{native[0]}">) : ''
    end
  end
end

Jekyll::Hooks.register [:posts, :pages, :documents], :post_render do |doc|
  next unless doc.output_ext == '.html'

  doc.output = ResponsiveImages.process(doc.output, doc.site.source)
end
