# frozen_string_literal: true

# A Markdown twin of every post (#192): /blog/2026/10/15/allan-nava-cragcast.md next to the
# .html, for the AI tools that look for a plain-text version of a page instead of reading it
# through the navigation, footer and scripts. _layouts/default.html links it with
# <link rel="alternate" type="text/markdown">, and /llms.txt points at the twins.
#
# The twin is the post's source, not its rendered HTML: a reduced front matter (title, date,
# description, the canonical URL), the title as an H1, then the body as written. What only
# makes sense to Jekyll is resolved or dropped: {% post_url %} becomes the post's URL,
# {{ site.url }} the site's, other Liquid tags and comments go; a YouTube facade becomes a link
# to the video.
#
# Written in a :post_write hook straight into the destination: a .md page given to Jekyll
# would be converted to HTML. So the twins are not in sitemap.xml (they are alternates of URLs
# that are) and cost no rendering, only one file write each.

require 'fileutils'
require 'json'

module MarkdownTwins
  FRONT_MATTER = /\A---[ \t]*\n.*?\n---[ \t]*\n/m.freeze
  FACADE = %r{<lite-youtube[^>]*\svideoid=["']([A-Za-z0-9_-]{6,})["'][^>]*>\s*</lite-youtube>}m.freeze

  module_function

  def twin_url(url)
    url.sub(/\.html\z/, '.md')
  end

  def body(source, site, posts_by_slug)
    text = source.sub(FRONT_MATTER, '')
    text = text.gsub(/\{%-?\s*comment\s*-?%\}.*?\{%-?\s*endcomment\s*-?%\}/m, '')
    text = text.gsub(/\{%-?\s*raw\s*-?%\}(.*?)\{%-?\s*endraw\s*-?%\}/m) { Regexp.last_match(1) }
    text = text.gsub(/\{%-?\s*post_url\s+(\S+)\s*-?%\}/) do
      post = posts_by_slug[Regexp.last_match(1)]
      post ? "#{site.config['url']}#{post.url}" : ''
    end
    text = text.gsub(/\{\{-?\s*site\.url\s*-?\}\}/, site.config['url'].to_s)
    text = text.gsub(/\{%.*?%\}/m, '').gsub(/\{\{.*?\}\}/m, '')
    text = text.gsub(/<!--.*?-->/m, '')
    text = text.gsub(FACADE) { "[Watch on YouTube](https://www.youtube.com/watch?v=#{Regexp.last_match(1)})" }
    text.gsub(/\n{3,}/, "\n\n").strip
  end

  def front_matter(post, site)
    data = post.data
    title = data['title'].to_s.gsub(/:[a-z0-9_+-]+:\s*/, '').strip
    lines = ['---', "title: #{title.to_json}", "date: #{post.date.iso8601}"]
    desc = data['description'].to_s.strip
    lines << "description: #{desc.to_json}" unless desc.empty?
    lines << "canonical: #{"#{site.config['url']}#{post.url}".to_json}"
    lines << "lang: #{data['lang']}" if data['lang']
    lines << '---'
    [lines.join("\n"), title]
  end
end

Jekyll::Hooks.register :site, :post_write do |site|
  posts = site.posts.docs
  by_slug = posts.to_h { |p| [File.basename(p.path, '.*'), p] }
  written = 0
  posts.each do |post|
    next unless post.url.end_with?('.html') && File.file?(post.path)

    head, title = MarkdownTwins.front_matter(post, site)
    text = MarkdownTwins.body(File.read(post.path, encoding: 'UTF-8'), site, by_slug)
    dest = File.join(site.dest, MarkdownTwins.twin_url(post.url))
    FileUtils.mkdir_p(File.dirname(dest))
    File.write(dest, "#{head}\n\n# #{title}\n\n#{text}\n")
    written += 1
  end
  Jekyll.logger.info 'Markdown:', "#{written} posts have a .md twin"
end
