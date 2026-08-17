source 'https://rubygems.org'

gem 'github-pages'
gem 'jekyll-admin'

# rake serve ai task del Rakefile (`rake test`, `rake test_internal`): senza,
# `bundle exec rake` fallisce con "rake is not currently included in the bundle".
gem 'rake'

# html-proofer pinnato alla 4.x: la 5.x richiede Ruby >= 3.1, mentre i workflow
# girano ancora su 3.0. Togliere il vincolo insieme al bump di Ruby (#128).
# La 3.x invece NON si può più usare: va in segmentation fault con il nokogiri
# che github-pages 232 si porta dietro.
gem 'html-proofer', '~> 4.4'
