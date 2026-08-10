# Riempie `image:` dei post video con la thumbnail del video.
#
# I post generati dal backfill YouTube non hanno `image:` (la feature è arrivata
# dopo), ma il body contiene sempre la facade <lite-youtube videoid="...">.
# Qui ricaviamo la thumbnail da quell'id, così le card dei listing e og:image
# hanno un'immagine senza toccare i 118 file in _posts/.
#
# Gira in build (Actions usa `bundle exec jekyll build`, non la safe-mode di
# GH Pages) e non modifica nulla su disco: solo i dati in memoria del documento.
module Jekyll
  class YouTubeThumbnails < Generator
    safe true
    priority :low

    VIDEO_ID = /<lite-youtube[^>]*\svideoid=["']([A-Za-z0-9_-]{6,})["']/.freeze

    def generate(site)
      filled = 0

      site.posts.docs.each do |post|
        next unless post.data['image'].to_s.strip.empty?

        match = VIDEO_ID.match(post.content.to_s)
        next unless match

        post.data['image'] = "https://i.ytimg.com/vi/#{match[1]}/hqdefault.jpg"
        post.data['thumbnail_from_youtube'] = true
        filled += 1
      end

      Jekyll.logger.info 'YouTube thumbnails:', "#{filled} post con thumbnail derivata dal videoid"
    end
  end
end
