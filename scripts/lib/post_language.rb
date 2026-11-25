# frozen_string_literal: true

# The language of a post, Italian or English, from its words (#194). Stdlib only, so
# validate_posts.rb can load it without bundle.
#
#   PostLanguage.detect("Foto di una gita al lago")   # => "it"
#   PostLanguage.of_post(front_matter, body)          # => "it", "en", or nil
#
# A stopword count: the short words a language cannot do without ("di", "che", "il";
# "the", "and", "of"). Words both languages use count for neither: "a", "in", "video",
# "me", "so", "come", "era", "ai" (AI), "all" (from "all'arrampicata"). nil when there are too few of them to tell (a post that is one photo and a
# title: fewer than two, or some of each), or when neither language clearly wins: then
# the page keeps the site's default.
#
# The callers:
#   scripts/set_post_language.rb   one-shot, writes `lang: it` into the Italian posts
#   scripts/validate_posts.rb      warns when a post's `lang` disagrees with its words
#   scripts/sync_youtube.rb        through with_lang: a new video post with Italian text
#   scripts/sync_github.rb         through with_lang: a new or rewritten project post
#   scripts/sync_strava.rb         not needed: its template is Italian, `lang: it` is fixed
module PostLanguage
  ITALIAN = %w[
    il lo la gli le un una uno di del dello della dei degli delle da dal dalla dai al allo
    alla agli alle nel nella nei nelle sul sulla sui con per tra fra che chi cui non
    anche ma se perché quando dove questo questa questi queste quello quella sono
    è ho hai ha abbiamo hanno essere stato stata mi ti si ci vi mio mia suo sua
    nostro più molto poco tutto tutti ogni dopo prima ancora già sempre oggi ieri domani
    qui ecco cosa fatto giorno anno
  ].freeze

  ENGLISH = %w[
    the and of to is are was were be been that this these those for with on at by from
    an or not but it its they them their we our you your he she his her what which who
    when where how why can could will would should have has had do does did my
    about into over after before more most some every one new just also than then
    there here out up if
  ].freeze

  MIN_HITS = 5     # fewer stopwords than this: a short text, judged by MIN_SHORT
  MIN_SHORT = 2    # a short text needs this many, and none of the other language
  MIN_SHARE = 0.65 # the winning language's share of the hits

  ITALIAN_SET = ITALIAN.to_h { |w| [w, true] }.freeze
  ENGLISH_SET = ENGLISH.to_h { |w| [w, true] }.freeze

  module_function

  # Text without what is not prose: fenced code, Liquid, HTML tags, URLs, link targets,
  # emoji shortcodes.
  def prose(text)
    text.to_s
        .gsub(/^```.*?^```/m, ' ')
        .gsub(/\{[{%].*?[%}]\}/m, ' ')
        .gsub(/<[^>]*>/m, ' ')
        .gsub(%r{https?://\S+}, ' ')
        .gsub(/\]\([^)]*\)/, '] ')
        .gsub(/:[a-z0-9_+-]+:/, ' ')
  end

  # [italian hits, english hits]
  def counts(text)
    it = 0
    en = 0
    prose(text).downcase.scan(/\p{L}+/) do |w|
      it += 1 if ITALIAN_SET[w]
      en += 1 if ENGLISH_SET[w]
    end
    [it, en]
  end

  def detect(text)
    it, en = counts(text)
    total = it + en
    if total < MIN_HITS
      # a line or two: a language only when the other has not a single word
      return 'it' if it >= MIN_SHORT && en.zero?
      return 'en' if en >= MIN_SHORT && it.zero?

      return nil
    end
    return 'it' if it >= total * MIN_SHARE
    return 'en' if en >= total * MIN_SHARE

    nil
  end

  # A post: its title, description and body together.
  def of_post(front_matter, body)
    fm = front_matter || {}
    detect([fm['title'], fm['description'], body].join("\n"))
  end

  FRONT_MATTER = /\A---[ \t]*\n(.*?)\n---[ \t]*\n/m.freeze

  # The text of a whole post (front matter and body), with `lang: it` and `locale: it_IT`
  # added at the end of the front matter when its words are Italian; unchanged otherwise,
  # or when it declares `lang` already. The sync scripts pass each post they write through
  # it, so a new post and a rewritten one are judged like set_post_language.rb judged the
  # rest. Needs `require 'yaml'` and `require 'date'` in the caller.
  def with_lang(post)
    m = post.match(FRONT_MATTER)
    return post unless m

    fm = YAML.safe_load(m[1], permitted_classes: [Date, Time]) || {}
    return post if fm['lang'] || of_post(fm, m.post_match) != 'it'

    "---\n#{m[1]}\nlang: it\nlocale: it_IT\n---\n#{m.post_match}"
  end
end
