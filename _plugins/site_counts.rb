# Sorgente unica dei conteggi del sito (#155).
#
# Prima ogni pagina se li ricalcolava in Liquid con filtri diversi — chi
# escludeva i post `hidden`, chi no, chi contava `site.tags` (che comprende i
# tag dei progetti) e chi solo quelli dei post. Risultato: home, /stats e
# /projects mostravano tre numeri diversi per la stessa cosa, e un visitatore
# che passava da una all'altra vedeva il sito contraddirsi.
#
# Le definizioni stanno qui, una volta, e i template leggono
# `site.data.counts.*`. Se un numero va cambiato, si cambia il criterio qui e
# cambia in tutte le pagine insieme.
module Jekyll
  class SiteCounts < Generator
    safe true
    priority :low

    def generate(site)
      posts = site.posts.docs

      # "Post" = quello che si trova su /blog: articoli, non schede di repo.
      blog = posts.select { |p| p.data['category'] == 'blog' && p.data['hidden'] != true }
      projects = posts.select { |p| p.data['projects'] }
      videos = posts.select { |p| p.content.to_s.include?('<lite-youtube') }
      geo = posts.select { |p| p.data['lat'] }

      # I tag contati sono quelli degli articoli: `site.tags` comprende anche i
      # tag dei progetti, e sulla home "Tags" sta accanto a "Posts".
      blog_tags = blog.flat_map { |p| Array(p.data['tag']) }.map(&:to_s).uniq

      site.data['counts'] = {
        'posts' => blog.size,
        'projects' => projects.size,
        'videos' => videos.size,
        'tags' => blog_tags.size,
        'all_tags' => site.tags.size,
        'geo' => geo.size,
        'total' => posts.size
      }

      Jekyll.logger.info 'Site counts:', site.data['counts'].map { |k, v| "#{k}=#{v}" }.join(' ')
    end
  end
end
