# Il CSS del sito come file in cache (#181), invece che inline in ogni pagina.
#
# Prima `_layouts/default.html` passava `_includes/style.scss` a `scssify` dentro un
# <style>: 106 KB ripetuti in ogni pagina (misurato su /about/, 148 KB di HTML) e mai
# in cache, piu' una compilazione Sass per ogni pagina della build.
#
# Qui il foglio si compila UNA volta per build: Liquid (per `{{ site.baseurl }}` nel
# @font-face), poi lo stesso convertitore Sass che usava `scssify`, poi il file
# `assets/css/main-<hash>.css`. Il nome contiene l'hash del contenuto, quindi:
#   - un browser puo' tenerlo in cache senza chiedere, e il service worker lo serve
#     cache-first (sw.js lo mette anche nel precache);
#   - cambia nome solo quando cambia il CSS, non a ogni build (il sito si ricostruisce
#     ogni ora per i sync): un deploy senza modifiche di stile non invalida niente.
# Il percorso finisce in `site.css_path`, che leggono il layout e sw.js.
#
# Il file e' uno StaticFile e non una Page: una Page passerebbe da Liquid e dagli
# hook dei plugin (lazy_images, responsive_images…), che sul CSS non hanno senso.

require 'digest'
require 'fileutils'
require 'tmpdir'

module SiteCss
  SOURCE = '_includes/style.scss'.freeze
  DIR = 'assets/css'.freeze

  class Generator < Jekyll::Generator
    safe true
    priority :high

    def generate(site)
      path = File.join(site.source, SOURCE)
      scss = File.read(path)

      template = site.liquid_renderer.file(path).parse(scss)
      rendered = template.render!(site.site_payload, registers: { site: site })

      converter = site.find_converter_instance(Jekyll::Converters::Scss)
      css = converter.convert(rendered)

      name = "main-#{Digest::SHA256.hexdigest(css)[0, 10]}.css"
      base = File.join(Dir.tmpdir, 'allan-nava-site-css')
      FileUtils.mkdir_p(File.join(base, DIR))
      File.write(File.join(base, DIR, name), css)

      site.static_files << Jekyll::StaticFile.new(site, base, DIR, name)
      site.config['css_path'] = "/#{DIR}/#{name}"
      Jekyll.logger.info 'Site CSS:', "#{site.config['css_path']} (#{css.bytesize} bytes)"
    end
  end
end
