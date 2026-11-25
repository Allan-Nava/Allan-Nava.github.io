# frozen_string_literal: true

# The small copy of a vertical video's thumbnail, for the listing cards (#187).
#
# scripts/cache_short_thumbs.rb writes assets/images/thumbs/<video id>-270.webp for every post
# whose `thumb:` is YouTube's 1080x1920 `oardefault.jpg`. Here each such post gets
# `thumb_small` (the copy's path) when the file exists; _includes/blog-post.html prefers it to
# `thumb`. A Short synced since the last run of the script has no copy yet and keeps the
# YouTube URL until the weekly image-optimize.yml makes one.

module ShortThumbs
  OAR = %r{\Ahttps://i\.ytimg\.com/vi/([A-Za-z0-9_-]{6,})/oardefault\.jpg\z}.freeze
  WIDTH = 270

  class Generator < Jekyll::Generator
    safe true
    priority :normal

    def generate(site)
      set = 0
      site.posts.docs.each do |post|
        id = post.data['thumb'].to_s[OAR, 1]
        next unless id

        rel = "/assets/images/thumbs/#{id}-#{WIDTH}.webp"
        next unless File.exist?(File.join(site.source, rel))

        post.data['thumb_small'] = rel
        set += 1
      end
      Jekyll.logger.info 'Thumbs:', "#{set} vertical thumbnails served from a #{WIDTH}px copy"
    end
  end
end
