require 'html-proofer'

# rake test
desc "build and test website"

task :test do
  sh "bundle exec jekyll build"
  HTMLProofer.check_directory("./_site",
    url_ignore: [/localhost/],
    only_4xx: true,
    # Allineati ai flag di .github/workflows/checks.yml, che è il gate vero.
    # `empty_alt_ignore`: alt="" è la marcatura corretta per le immagini
    # decorative (avatar della nav, thumbnail delle card, dove il nome
    # accessibile lo dà il link) — senza questo html-proofer 3 le segnala tutte.
    empty_alt_ignore: true,
    allow_hash_href: true,
    assume_extension: true
  ).run
end

desc "build and test website without checking external links"
task :test_internal do
  sh "bundle exec jekyll build"
  HTMLProofer.check_directory("./_site",
    url_ignore: [/localhost/],
    only_4xx: true,
    empty_alt_ignore: true,
    allow_hash_href: true,
    assume_extension: true,
    disable_external: true
  ).run
end
