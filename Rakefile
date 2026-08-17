require 'html-proofer'

# Opzioni condivise dai due task, allineate ai flag di .github/workflows/checks.yml
# — che è il gate vero: se qui e lì divergono, "verde in locale" non vuol dire
# niente.
#
# NB: i nomi sono quelli di html-proofer **4.x**, rinominati rispetto alla 3.x
# (`url_ignore` → `ignore_urls`, `empty_alt_ignore` → `ignore_empty_alt`) e
# `assume_extension` ora vuole la stringa dell'estensione, non `true`.
#
# `ignore_empty_alt`: alt="" è la marcatura corretta per le immagini decorative
# (avatar della nav, thumbnail delle card, dove il nome accessibile lo dà il
# link). Un alt **mancante** del tutto resta un errore, ed è giusto così.
PROOFER_OPTIONS = {
  ignore_urls: [/localhost/],
  only_4xx: true,
  ignore_empty_alt: true,
  allow_hash_href: true,
  assume_extension: '.html'
}.freeze

# NB: sempre una COPIA delle opzioni. html-proofer 5 **modifica** l'hash che gli
# passi, e PROOFER_OPTIONS è `freeze`d: passarlo direttamente fa esplodere il
# task con `FrozenError: can't modify frozen Hash`. Non si vedeva con la 4.x, e
# `test_internal` se la cavava per caso perché `merge` restituisce già una copia.
desc 'build and test website'
task :test do
  sh 'bundle exec jekyll build'
  HTMLProofer.check_directory('./_site', PROOFER_OPTIONS.dup).run
end

desc 'build and test website without checking external links'
task :test_internal do
  sh 'bundle exec jekyll build'
  HTMLProofer.check_directory('./_site', PROOFER_OPTIONS.merge(disable_external: true)).run
end
