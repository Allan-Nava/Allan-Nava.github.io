# Filtri Liquid per il testo.
#
# strip_emoji_shortcodes: toglie gli shortcode di jemoji (`:video_camera:`) da un titolo,
# per le pagine che il titolo lo mettono in un posto dove jemoji non deve passare. Su /map
# un solo shortcode in pagina fa ri-parsare a jemoji tutto il documento, script compresi
# (vedi la nota in map.html): li' i titoli escono senza, invece che col codice in chiaro.
#   {{ post.title | strip_emoji_shortcodes }}   ":video_camera: Lisboa vibes" -> "Lisboa vibes"
module TextFilters
  SHORTCODE = /:[a-z0-9_+-]+:\s*/.freeze

  def strip_emoji_shortcodes(input)
    input.to_s.gsub(SHORTCODE, '').strip
  end
end

Liquid::Template.register_filter(TextFilters)
