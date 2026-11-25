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
#   5. Titles over 70 characters (18, nearly all videos: emoji, hashtags) get a `seo_title`
#      without them, cut to fit. The visible heading keeps the full title.
#   6. Descriptions still under 50 characters (38: a blog post's one line, a project without a
#      repository) say what the post is, whose, when, and its tags. Both from #193.
#
# A Generator for 1, 2, 4, 5 and 6 (it runs after video_descriptions.rb and youtube_thumbnails.rb,
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

      # 1. duplicate titles: the date, and the time too when two share the day
      dated = 0
      posts.group_by { |p| p.data['title'].to_s.strip }.each_value do |group|
        next if group.size < 2

        same_day = group.map { |p| p.date.strftime('%F') }.tally
        group.each do |p|
          next if p.data['seo_title']

          when_ = same_day[p.date.strftime('%F')] > 1 ? p.date.strftime('%-d %b %Y, %H:%M') : p.date.strftime('%-d %b %Y')
          p.data['seo_title'] = "#{p.data['title']} (#{when_}) | #{site.config['title']}"
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

      # 2b. a description shared by several posts (two projects from one repository family,
      # two videos of one holiday) is led by each post's own title.
      shared = 0
      posts.group_by { |p| p.data['description'].to_s.strip }.each do |desc, group|
        next if desc.empty? || group.size < 2

        group.each do |p|
          title = p.data['title'].to_s.gsub(SHORTCODE, '').strip
          next if desc.start_with?(title)

          p.data['card_description'] ||= desc unless p.data['description_generated']
          p.data['description'] = "#{title} — #{desc}"
          shared += 1
        end
      end

      # 4. the video of a video post
      videos = 0
      posts.each do |p|
        id = p.content.to_s[VIDEO_ID, 1]
        next unless id

        p.data['video_id'] = id
        videos += 1
      end

      # 5. titles too long for a search result: the video titles, with emoji and hashtags
      suffix = " | #{site.config['title']}"
      trimmed = 0
      posts.each do |p|
        title = p.data['title'].to_s.strip
        next if p.data['seo_title'] || (title + suffix).length <= SiteSEO::TITLE_MAX

        p.data['seo_title'] = SiteSEO.search_title(title, suffix) + suffix
        trimmed += 1
      end

      # 6. descriptions still under 50 characters (a blog post's one line, a project without
      # a repository): what it is, whose, when, and its tags.
      lengthened = 0
      posts.each do |p|
        desc = p.data['description'].to_s.strip
        next if desc.empty? || desc.length >= SiteSEO::DESCRIPTION_MIN

        title = SiteSEO.plain(p.data['title'])
        lead = SiteSEO.plain(desc.sub(/\AAllan Nava\s*[-–:]?\s*/i, '')).sub(/[.\s]+\z/, '')
        lead = title if lead.empty? || title.downcase.include?(lead.downcase)
        lead = lead[0].upcase + lead[1..]
        kind = p.data['category'] == 'project' ? 'a project' : 'a post'
        tags = Array(p.data['tags']).map(&:to_s).reject(&:empty?).first(4)
        p.data['card_description'] ||= desc unless p.data['description_generated']
        p.data['description'] = "#{lead}: #{kind} by #{author}, #{p.date.strftime('%B %Y')}" +
                                (tags.empty? ? '' : " (#{tags.join(', ')})") + '.'
        lengthened += 1
      end

      Jekyll.logger.info 'SEO:', "#{dated} titles dated, #{enriched} project descriptions, #{shared} shared descriptions led by their title, #{videos} videos, #{trimmed} titles trimmed, #{lengthened} descriptions lengthened"
    end
  end

  # The audit's limits (scripts/seo_audit.rb fails on a page past them).
  TITLE_MAX = 70
  DESCRIPTION_MIN = 50

  # Emoji and other symbols: the category So (pictographs, 🔹, ♦), Sk (skin tones), Cf (the
  # zero-width joiner), and the emoji variation selector.
  SYMBOL = /[\p{So}\p{Sk}\p{Cf}\u{FE0F}]/.freeze
  HASHTAG = /(?<![\w&])#[\p{L}\p{N}_]+/.freeze

  # The title without shortcodes, emoji, or the separators made of them.
  def self.plain(text)
    text.to_s.gsub(SHORTCODE, ' ').gsub(SYMBOL, ' ').gsub(/\s+/, ' ').strip.sub(/\A[\s·-]+/, '').sub(/[\s·-]+\z/, '')
  end

  # "Nayt - Se ne va 🔹 Release Party Lettera Q ~ Dazi Milano #rap #hiphop" becomes
  # "Nayt - Se ne va · Release Party Lettera Q · Dazi Milano": hashtags go, a run of emoji
  # (or a ~) between words becomes " · ". Still too long, whole segments go from the end,
  # and then words, with an ellipsis. The visible heading keeps the full title.
  def self.search_title(title, suffix)
    room = TITLE_MAX - suffix.length
    t = title.gsub(HASHTAG, ' ').gsub(SHORTCODE, ' ').gsub(SYMBOL, "\0").tr('~', "\0")
    t = t.gsub(/[\s\0]*\0[\s\0]*/, ' · ').gsub(/\s+/, ' ').sub(/\A[\s·-]+/, '').sub(/[\s·-]+\z/, '')
    parts = t.split(' · ')
    parts.pop while parts.size > 1 && parts.join(' · ').length > room
    t = parts.join(' · ')
    return t if t.length <= room

    cut = t[0, room - 1]
    cut = cut[0, cut.rindex(' ')] if cut.include?(' ')
    "#{cut.sub(/[\s·,:;.-]+\z/, '')}…"
  end
end

# 3. paginated blog pages: "… Page 7 of 23." The base is kept in `description_base`, so a
# second render of the same page does not append twice.
# The payload's "page" is a copy of the data made before this hook runs, and it is what
# jekyll-seo-tag reads: both are set.
Jekyll::Hooks.register :pages, :pre_render do |page, payload|
  pager = page.respond_to?(:pager) ? page.pager : nil
  next unless pager && pager.page.to_i > 1

  base = (page.data['description_base'] ||= page.data['description'].to_s.strip)
  next if base.empty?

  description = "#{base.sub(/[.\s]+\z/, '')}. Page #{pager.page} of #{pager.total_pages}."
  page.data['description'] = description
  payload['page']['description'] = description if payload['page'].respond_to?(:[]=)
end
