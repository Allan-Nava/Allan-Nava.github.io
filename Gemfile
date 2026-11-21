source 'https://rubygems.org'

gem 'github-pages'

# L'interfaccia /admin di `jekyll serve` (crea e modifica post e config dal browser): solo in
# locale, non entra nel sito pubblicato. Sta nel gruppo :development perche' si porta dietro
# rack 1.6 e sinatra 1.4, da cui veniva quasi tutto dei 51 alert di Dependabot (#184); i
# workflow girano con BUNDLE_WITHOUT=development e non la installano.
group :development do
  gem 'jekyll-admin'
end

# rake serve ai task del Rakefile (`rake test`, `rake test_internal`): senza,
# `bundle exec rake` fallisce con "rake is not currently included in the bundle".
gem 'rake'

# html-proofer 5.x: richiede Ruby >= 3.1, quindi può stare qui solo perché i
# workflow girano su 3.3 (#128, passo 2). Non tornare sotto la 4: la 3.x va in
# segmentation fault con il nokogiri che github-pages 232 si porta dietro.
gem 'html-proofer', '~> 5.0'
