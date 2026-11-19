#!/usr/bin/env ruby
# frozen_string_literal: true

# IndexNow: dice a Bing (e quindi a DuckDuckGo, che usa il suo indice), Yandex e agli
# altri motori del protocollo quali URL sono nuovi o cambiati, invece di aspettare che
# li trovino ripassando dalla sitemap. Google non partecipa: per Google resta la sitemap.
#
#   ruby scripts/indexnow.rb diff OLD.xml NEW.xml > urls.txt
#       gli URL di NEW che in OLD non c'erano, o con un <lastmod> diverso
#   ruby scripts/indexnow.rb all NEW.xml > urls.txt
#       tutti gli URL di NEW (primo invio, o dopo un cambio di URL)
#   ruby scripts/indexnow.rb submit urls.txt
#       li invia (POST a api.indexnow.org, al massimo 10.000 per richiesta)
#
# La chiave e' il file <chiave>.txt alla radice del repo, pubblicato alla radice del
# sito: e' pubblica per costruzione (il motore la scarica per verificare che l'invio
# venga dal proprietario del dominio), non e' un segreto. Una sola chiave: il file e'
# l'unico *.txt di 32 caratteri esadecimali nella radice.
#
# Gira in .github/workflows/jekyll.yml: `diff` nel job di build, contro la sitemap
# ancora online; `submit` in un job dopo il deploy, cosi' gli URL esistono gia'.
# DRY_RUN=1 stampa invece di inviare. Solo stdlib.

require 'json'
require 'net/http'
require 'uri'

HOST = 'allan-nava.github.io'
ENDPOINT = URI('https://api.indexnow.org/indexnow')
BATCH = 10_000

def entries(path)
  xml = File.exist?(path) ? File.read(path) : ''
  xml.scan(%r{<url>(.*?)</url>}m).to_h do |(block)|
    loc = block[%r{<loc>(.*?)</loc>}m, 1].to_s.strip
    lastmod = block[%r{<lastmod>(.*?)</lastmod>}m, 1].to_s.strip
    [loc, lastmod]
  end.reject { |loc, _| loc.empty? }
end

def key
  root = File.expand_path('..', __dir__)
  files = Dir.children(root).grep(/\A[0-9a-f]{32}\.txt\z/)
  abort "indexnow: expected one <32 hex>.txt key file in the repo root, found #{files.size}" unless files.size == 1
  File.basename(files.first, '.txt')
end

case ARGV[0]
when 'diff'
  old = entries(ARGV.fetch(1))
  new = entries(ARGV.fetch(2))
  abort 'indexnow: the new sitemap has no URLs' if new.empty?
  # Senza una sitemap precedente (primo deploy, sito irraggiungibile) non si inventa un
  # diff: si invia niente, e il primo invio completo si fa a mano con `all`.
  if old.empty?
    warn 'indexnow: no previous sitemap, nothing to compare: run the workflow with indexnow_all'
    exit 0
  end
  changed = new.select { |loc, lastmod| old[loc] != lastmod }.keys
  warn "indexnow: #{changed.size} of #{new.size} URLs new or changed"
  puts changed
when 'all'
  urls = entries(ARGV.fetch(1)).keys
  warn "indexnow: all #{urls.size} URLs"
  puts urls
when 'submit'
  urls = File.readlines(ARGV.fetch(1), chomp: true).map(&:strip).reject(&:empty?)
  urls.select! { |u| URI(u).host == HOST }
  if urls.empty?
    puts 'indexnow: nothing to submit'
    exit 0
  end
  k = key
  urls.each_slice(BATCH) do |batch|
    body = { host: HOST, key: k, keyLocation: "https://#{HOST}/#{k}.txt", urlList: batch }
    if ENV['DRY_RUN'] == '1'
      puts "indexnow (dry run): #{batch.size} URLs", batch.first(10)
      next
    end
    res = Net::HTTP.post(ENDPOINT, body.to_json, 'Content-Type' => 'application/json; charset=utf-8')
    # 200 accettato, 202 accettato con la verifica della chiave in sospeso (succede al
    # primo invio). 403 chiave non trovata, 422 URL fuori dal dominio, 429 troppi invii.
    puts "indexnow: #{batch.size} URLs -> HTTP #{res.code}"
    abort "indexnow: #{res.code} #{res.body}" unless %w[200 202].include?(res.code)
  end
else
  abort 'usage: indexnow.rb diff OLD.xml NEW.xml | all NEW.xml | submit urls.txt'
end
