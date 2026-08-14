#!/usr/bin/env ruby
# Verifica il contrasto WCAG delle coppie di colore della palette, su TUTTI i
# temi definiti in _sass/base/tokens.scss (#137).
#
# I valori non sono duplicati qui: vengono letti dai mixin `palette-dark` e
# `palette-light` del file, così se qualcuno cambia un token il controllo segue.
# Il tema scuro è il default e il chiaro una sua ridefinizione: un colore
# aggiunto a un solo mixin è il modo tipico di rendere qualcosa invisibile
# nell'altro tema, e questo script lo intercetta (vedi "token solo in ...").
#
# Uso: ruby scripts/check_contrast.rb
#   env MIN=6.0   soglia richiesta (default 6.0: AA con margine, come v2.3)
#
# Stdlib only, così gira senza bundle install.

ROOT = File.expand_path('..', __dir__)
TOKENS = File.join(ROOT, '_sass', 'base', 'tokens.scss')
MIN = Float(ENV.fetch('MIN', '6.0'))

# --- lettura dei mixin -------------------------------------------------------

def parse_palettes(path)
  src = File.read(path, encoding: 'UTF-8')
  # I commenti vanno via PRIMA della scansione: qui dentro si citano nomi di
  # token ("… ≥ 6:1 su --color-code-bg: la palette scura …") e un regex ingenuo
  # li scambia per dichiarazioni, ingoiando tutto fino al `;` successivo.
  src = src.gsub(%r{/\*.*?\*/}m, '').gsub(%r{//[^\n]*}, '')

  palettes = {}
  src.scan(/@mixin\s+palette-(\w+)\s*\{(.*?)\n\}/m) do |name, body|
    tokens = {}
    # Ancorata a inizio riga: una dichiarazione vera sta sempre su una riga sua.
    body.scan(/^\s*(--[\w-]+):\s*([^;]+);/) { |k, v| tokens[k] = v.strip }
    palettes[name] = tokens
  end
  palettes
end

# --- colore -----------------------------------------------------------------

def parse_color(value)
  v = value.strip
  if (m = v.match(/\A#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})\z/))
    h = m[1]
    h = h.chars.map { |c| c * 2 }.join if h.length == 3
    [h[0, 2].to_i(16), h[2, 2].to_i(16), h[4, 2].to_i(16), 1.0]
  elsif (m = v.match(/\Argba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)\z/))
    [m[1].to_i, m[2].to_i, m[3].to_i, (m[4] || '1').to_f]
  end
end

def composite(fg, bg)
  a = fg[3]
  (0..2).map { |i| (fg[i] * a + bg[i] * (1 - a)).round }.push(1.0)
end

def luminance(c)
  lin = (0..2).map do |i|
    s = c[i] / 255.0
    s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055)**2.4
  end
  0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]
end

def contrast(fg, bg)
  f = fg[3] < 1 ? composite(fg, bg) : fg
  l1 = luminance(f)
  l2 = luminance(bg)
  hi = [l1, l2].max
  lo = [l1, l2].min
  ((hi + 0.05) / (lo + 0.05))
end

# --- coppie da controllare --------------------------------------------------
# [etichetta, token del primo piano, token dello sfondo]
# Lo sfondo può essere composto: --color-accent-soft è translucido e va
# valutato sopra --color-bg, non da solo.
PAIRS = [
  ['fg / bg',                      '--color-fg',           '--color-bg'],
  ['fg-strong / bg',               '--color-fg-strong',    '--color-bg'],
  ['fg-muted / bg',                '--color-fg-muted',     '--color-bg'],
  ['fg / surface',                 '--color-fg',           '--color-surface'],
  ['fg-muted / surface',           '--color-fg-muted',     '--color-surface'],
  ['fg-muted / surface-hover',     '--color-fg-muted',     '--color-surface-hover'],
  ['accent come testo / bg',       '--color-accent',       '--color-bg'],
  ['accent come testo / surface',  '--color-accent',       '--color-surface'],
  ['accent-hover / bg',            '--color-accent-hover', '--color-bg'],
  ['on-accent / accent',           '--color-on-accent',    '--color-accent'],
  ['code-fg / code-bg',            '--color-code-fg',      '--color-code-bg'],
  ['accent-text / accent-soft',    '--color-accent-text',  '--color-accent-soft', '--color-bg'],
  ['syn-comment / code-bg',        '--syn-comment',        '--color-code-bg'],
  ['syn-preproc / code-bg',        '--syn-preproc',        '--color-code-bg'],
  ['syn-keyword / code-bg',        '--syn-keyword',        '--color-code-bg'],
  ['syn-string / code-bg',         '--syn-string',         '--color-code-bg'],
  ['syn-number / code-bg',         '--syn-number',         '--color-code-bg'],
  ['syn-type / code-bg',           '--syn-type',           '--color-code-bg'],
  ['syn-func / code-bg',           '--syn-func',           '--color-code-bg'],
  ['syn-var / code-bg',            '--syn-var',            '--color-code-bg'],
  ['syn-punct / code-bg',          '--syn-punct',          '--color-code-bg'],
  ['syn-lineno / code-bg',         '--syn-lineno',         '--color-code-bg'],
  ['syn-heading / code-bg',        '--syn-heading',        '--color-code-bg'],
  ['syn-err / code-bg',            '--syn-err',            '--color-code-bg'],
  ['syn-del / code-bg',            '--syn-del',            '--color-code-bg'],
  ['syn-ins / code-bg',            '--syn-ins',            '--color-code-bg']
].freeze

palettes = parse_palettes(TOKENS)
abort "Nessun @mixin palette-* trovato in #{TOKENS}" if palettes.empty?

errors = []
checked = 0

# Un token presente in un solo tema è un colore che non cambia quando il tema
# cambia: in v2.3 è esattamente così che `strong` e `code` sono diventati
# invisibili. Meglio accorgersene qui che a occhio.
names = palettes.keys
all_keys = palettes.values.map(&:keys).reduce(:|)
all_keys.sort.each do |k|
  missing = names.reject { |n| palettes[n].key?(k) }
  next if missing.empty?

  errors << "#{k}: definito solo in #{(names - missing).join(', ')} — manca in #{missing.join(', ')}"
end

palettes.each do |theme, tokens|
  puts "\n===== #{theme.upcase} ====="
  PAIRS.each do |label, fg_key, bg_key, under_key|
    fg_raw = tokens[fg_key]
    bg_raw = tokens[bg_key]
    next unless fg_raw && bg_raw

    fg = parse_color(fg_raw)
    bg = parse_color(bg_raw)
    unless fg && bg
      errors << "#{theme}: colore non interpretabile in '#{label}' (#{fg_raw} / #{bg_raw})"
      next
    end

    if bg[3] < 1
      under = under_key && parse_color(tokens[under_key])
      unless under
        errors << "#{theme}: '#{label}' ha uno sfondo translucido senza base su cui valutarlo"
        next
      end
      bg = composite(bg, under)
    end

    ratio = contrast(fg, bg)
    checked += 1
    ok = ratio >= MIN
    errors << "#{theme}: #{label} = #{format('%.2f', ratio)}:1 (serve #{MIN})" unless ok
    puts format('  [%s] %-30s %5.2f:1', ok ? 'ok ' : 'NO!', label, ratio)
  end
end

puts
if errors.empty?
  puts "#{checked} coppie verificate su #{palettes.size} temi, tutte >= #{MIN}:1."
  exit 0
end

puts "#{errors.size} problema/i:"
errors.each { |e| puts "  - #{e}" }
exit 1
