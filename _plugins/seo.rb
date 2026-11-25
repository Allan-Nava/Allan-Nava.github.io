# Search engines: what the crawl of the live site found on 2026-11-25, fixed at build time
# without touching the posts (so the synced ones get it too).
#
#   1. Duplicate titles: 13 posts shared their <title> with another (videos published under
#      the same name: "Padel Garden Tennis Club" three times). Each of them gets the date in
#      its <title> through `seo_title`, which _layouts/default.html prefers.
#   2. Thin project descriptions: 76 project posts had the repository's one-liner as their
#      description, often just its name ("HelloWorldSwift"). One shorter than 60 characters,
#      or equal to the title, becomes a sentence that says what and whose it is. The listing
#      cards keep showing the original, through `card_description`.
#   3. The blog's 23 paginated pages all had the same description. Page N of M says so.
#   4. Video posts: the YouTube id of the first facade goes in `video_id`, for the VideoObject
#      JSON-LD of _includes/schema-video.html (Google's video results need it).
#
# A Generator for 1, 2 and 4 (it runs after video_descriptions.rb and youtube_thumbnails.rb,
# both :low), a pre_render hook for 3 (the paginated pages exist only after pagination).

module SiteSEO
  SHORTCODE = /:[a-z0-9_+-]+:\s*/.freeze
  VIDEO_ID = /<lite-youtube[^>]*\svideoid=["']([A-Za-z0-9_-]{6,})["']/.freeze
  LANGUAGE = /\*\*Linguaggio\*\*:\s*([^\n]+)/.freeze

  class Generator < Jekyll::Generator
    safe true
    priority :lowest

    def generate(site)
      author = (site.data['authors'] || {}).dig('allan', 'name') || site.config['title']
      posts = site.posts.docs

      # 1. duplicate titles
      dated = 0
      posts.group_by { |p| p.data['title'].to_s.strip }.each_value do |group|
        next if group.size < 2

        group.each do |p|
          next if p.data['seo_title']

          p.data['seo_title'] = "#{p.data['title']} (#{p.date.strftime('%-d %b %Y')}) | #{site.config['title']}"
          dated += 1
        end
      end

      # 2. thin project descriptions
      enriched = 0
      posts.each do |p|
        next unless p.data['category'] == 'project' && p.data['github']

        title = p.data['title'].to_s.strip
        desc = p.data['description'].to_s.strip
        next unless desc.length < 60 || desc.casecmp?(title)

        language = p.content.to_s[LANGUAGE, 1].to_s.strip
        what = language.empty? || language.casecmp?('n/a') ? 'an open-source project' : "an open-source #{language} project"
        lead = desc.empty? || desc.casecmp?(title) ? title : "#{title} — #{desc.sub(/[.\s]+\z/, '')}"
        p.data['card_description'] = desc unless desc.empty?
        p.data['description'] = "#{lead}: #{what} by #{author} on GitHub (#{p.data['github']})."
        enriched += 1
      end

      # 4. the video of a video post
      videos = 0
      posts.each do |p|
        id = p.content.to_s[VIDEO_ID, 1]
        next unless id

        p.data['video_id'] = id
        videos += 1
      end

      Jekyll.logger.info 'SEO:', "#{dated} titles dated, #{enriched} project descriptions, #{videos} videos"
    end
  end
end

# 3. paginated blog pages: "… Page 7 of 23." The base is kept in `description_base`, so a
# second render of the same page does not append twice.
Jekyll::Hooks.register :pages, :pre_render do |page, _payload|
  pager = page.respond_to?(:pager) ? page.pager : nil
  next unless pager && pager.page.to_i > 1

  base = (page.data['description_base'] ||= page.data['description'].to_s.strip)
  next if base.empty?

  page.data['description'] = "#{base.sub(/[.\s]+\z/, '')}. Page #{pager.page} of #{pager.total_pages}."
end
