# Una description per i post video che non ne hanno (#185).
#
# 134 post su 135 con `description: ""` sono video YouTube (133 senza alcun testo nel
# corpo, solo la facade <lite-youtube>): ricadevano tutti su `site.description`, quindi per
# i motori 134 pagine avevano la stessa meta description e la stessa description nel JSON-LD, e feed e
# ricerca non avevano niente da mostrare.
#
# Qui la si compone, a build time, da quello che il post ha: titolo, autore, data di
# pubblicazione e se il video e' verticale (`thumb:` = oardefault.jpg, vedi CLAUDE.md
# "Anteprime YouTube"). Non e' il boilerplate tolto in v2.7 (#162), che ripeteva solo il
# titolo: questa dice anche chi, quando e che tipo di video, ed e' diversa per ogni post.
#   "Dips 55kg: a short video Allan Nava published on YouTube on 9 January 2025."
# I tag non entrano: su questi post sono solo `youtube` piu' `short` o `video` (contati il
# 2026-11-21 su tutti e 134), cioe' niente che il resto della frase non dica gia'. La data
# e' quella del post, cioe' della pubblicazione, non delle riprese: "Bal Harbour 2018" e'
# uscito nel 2026, per questo "published".
#
# I file non si toccano: vale anche per i video che i sync aggiungeranno. Il post riceve
# `description_generated: true`, e le card dei listing (index.html, projects.html,
# _includes/blog-post.html), che mostrano la description come estratto, la saltano: li' una
# frase uguale per tutti sarebbe solo rumore. La usano meta tag, JSON-LD, feed e ricerca.
#
# Un Generator e non un hook di render: gira prima di qualunque pagina, quindi anche i
# listing e search.json vedono la description gia' impostata, in qualunque ordine Jekyll
# renderizzi.

module VideoDescriptions
  SHORTCODE = /:[a-z0-9_+-]+:\s*/.freeze

  class Generator < Jekyll::Generator
    safe true
    priority :low

    def generate(site)
      author = (site.data['authors'] || {}).dig('allan', 'name') || site.config['title']
      count = 0
      site.posts.docs.each do |post|
        next unless post.data['description'].to_s.strip.empty?
        next unless post.content.include?('<lite-youtube')

        post.data['description'] = describe(post, author)
        post.data['description_generated'] = true
        count += 1
      end
      Jekyll.logger.info 'Video descriptions:', "#{count} generated"
    end

    private

    def describe(post, author)
      title = post.data['title'].to_s.gsub(SHORTCODE, '').gsub(/<[^>]+>/, '').strip
      kind = post.data['thumb'].to_s.include?('oardefault') ? 'a short video' : 'a video'
      date = post.date.strftime('%-d %B %Y')
      "#{title}: #{kind} #{author} published on YouTube on #{date}."
    end
  end
end
