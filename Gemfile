source 'https://rubygems.org'

gem 'github-pages'

# jekyll-admin (l'interfaccia /admin di `jekyll serve`) e' stato tolto (#184): non lo usava
# nessuno, e si portava dietro rack 1.6 e sinatra 1.4, da cui venivano 40 dei 51 alert di
# Dependabot. I post si scrivono a mano o arrivano dagli script di sync.

# rake serve ai task del Rakefile (`rake test`, `rake test_internal`): senza,
# `bundle exec rake` fallisce con "rake is not currently included in the bundle".
gem 'rake'

# html-proofer 5.x: richiede Ruby >= 3.1, quindi può stare qui solo perché i
# workflow girano su 3.3 (#128, passo 2). Non tornare sotto la 4: la 3.x va in
# segmentation fault con il nokogiri che github-pages 232 si porta dietro.
gem 'html-proofer', '~> 5.0'
