# frozen_string_literal: true
#
# Adds native lazy-loading to content images at build time: sets loading="lazy"
# and async image decoding on every content <img>.
#
# kramdown can't set a global img attribute, so Markdown photos in posts would
# otherwise load eagerly. This runs because the site is built with a full
# `bundle exec jekyll build` in CI (see .github/workflows/jekyll.yml), not
# GitHub Pages' safe mode — so custom _plugins/ are executed.
#
# Skips images already carrying a loading attribute, and the above-the-fold
# hero images (post `title-image`, profile `selfie`) which are LCP candidates
# and must stay eager.
module LazyImages
  IMG = /<img(?![^>]*\bloading=)(?![^>]*\b(?:title-image|selfie)\b)/i
  ATTRS = '<img loading="lazy" ' + 'decoding="async"'

  def self.process(html)
    html.gsub(IMG, ATTRS)
  end
end

Jekyll::Hooks.register [:posts, :pages, :documents], :post_render do |doc|
  next unless doc.output_ext == '.html'
  doc.output = LazyImages.process(doc.output)
end
