# frozen_string_literal: true

# <lastmod> for pages in sitemap.xml (#188), from git: the date of the last commit that
# touched the page's file.
#
# jekyll-sitemap writes <lastmod> from `last_modified_at` (or `date`), and only posts have a
# date; pages such as /map/, /stack/ or /about/ had none. scripts/indexnow.rb submits the URLs
# that are new or whose <lastmod> changed, so a changed page was never submitted: the deploy
# after the /map/ redesign found "0 of 439 URLs new or changed".
#
# One `git log` for the whole history, not one per page. Nothing is set when git is missing or
# the clone is shallow: there every file would carry the date of the one commit checked out,
# and IndexNow would resubmit every page at every deploy. jekyll.yml checks out with
# `fetch-depth: 0` for this. A page that declares `last_modified_at` keeps its own; generated
# pages (the blog's pagination, tags) have no file of their own and get nothing.
# The date is the file's: /map/ changes when map.html does, not when a post adds a marker.

require 'open3'
require 'time'

module PageLastmod
  class Generator < Jekyll::Generator
    safe true
    priority :high # before jekyll-sitemap, which is :lowest

    def generate(site)
      dates = commit_dates(site.source)
      return Jekyll.logger.info('Lastmod:', 'no git history (shallow clone or no git), pages keep no <lastmod>') unless dates

      set = 0
      site.pages.each do |page|
        next if page.data['last_modified_at'] || page.data['sitemap'] == false

        path = page.relative_path.to_s.delete_prefix('/')
        next unless (date = dates[path])

        page.data['last_modified_at'] = date
        set += 1
      end
      Jekyll.logger.info 'Lastmod:', "#{set} pages dated from git"
    end

    private

    # { "map.html" => Time of the newest commit that touched it }
    def commit_dates(source)
      shallow, status = Open3.capture2('git', '-C', source, 'rev-parse', '--is-shallow-repository')
      return nil unless status.success? && shallow.strip == 'false'

      out, status = Open3.capture2('git', '-C', source, '-c', 'core.quotepath=off', 'log', '--format=@%cI', '--name-only', '--no-renames', '--', '.')
      return nil unless status.success?

      dates = {}
      current = nil
      out.each_line do |line|
        line = line.chomp
        if line.start_with?('@')
          current = Time.iso8601(line[1..])
        elsif !line.empty?
          dates[line] ||= current # newest first: the first time a file appears is its last change
        end
      end
      dates
    end
  end
end
