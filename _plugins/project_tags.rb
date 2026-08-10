# Costruisce l'elenco dei tag usati dai post progetto, ordinato per frequenza.
#
# Serve ai chip di filtro di /projects: con 154 progetti i tag distinti sono
# troppi per essere mostrati tutti, e Liquid non sa ordinare una mappa per
# valore. Qui si calcola una volta a build time e il template legge
# `site.data.project_tags`.
module Jekyll
  class ProjectTags < Generator
    safe true
    priority :low

    TOP_N = 12

    def generate(site)
      # Il conteggio è per **slug** e per **post**, non per occorrenza del nome:
      # è l'unico modo perché il numero sul chip coincida con le card che
      # restano dopo il filtro (il template confronta gli stessi slug, e "Go" e
      # "go" sono lo stesso filtro).
      counts = Hash.new(0)
      labels = {}

      site.posts.docs.each do |post|
        next unless post.data['projects']

        slugs = Array(post.data['tag']).map { |tag| Utils.slugify(tag.to_s) }.reject(&:empty?).uniq

        slugs.each do |slug|
          counts[slug] += 1
          labels[slug] ||= Array(post.data['tag']).find { |tag| Utils.slugify(tag.to_s) == slug }.to_s
        end
      end

      top = counts.sort_by { |slug, count| [-count, slug] }.first(TOP_N)

      site.data['project_tags'] = top.map do |slug, count|
        { 'name' => labels[slug], 'slug' => slug, 'count' => count }
      end

      Jekyll.logger.info 'Project tags:', "#{counts.size} tag distinti, #{top.size} nei filtri"
    end
  end
end
