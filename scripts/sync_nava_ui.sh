#!/usr/bin/env bash
# Il sito legge i design token da nava-ui (https://github.com/Allan-Nava/nava-ui), il kit
# estratto da questo sito: la copia dei token sta in _sass/vendor/_nava-tokens.scss ed e' il file
# `dist/tokens.site.scss` di una versione fissata del kit, cioe' i token gia' nel dialetto
# del sito (nomi --color-*, rem da 10px, mixin palette-dark / palette-light / scale).
#
#   scripts/sync_nava_ui.sh v0.3.0    copia i token di quella versione (aggiornare = cambiare tag)
#   scripts/sync_nava_ui.sh --check   la copia e' identica al file del tag che dichiara?
#                                     Gira in checks.yml: una copia modificata a mano fallisce.
#
# I colori si cambiano nel kit, non qui: si fa un rilascio del kit e si rilancia questo script
# col tag nuovo. La versione fissata e' scritta nella prima riga della copia
# ("GENERATED from nava-ui vX.Y.Z"), quindi non c'e' un secondo posto da tenere allineato.
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET="_sass/vendor/_nava-tokens.scss"
# I componenti del kit usati dal sito: uno per sezione di css/components.css del kit, gia'
# col rem da 10px e senza commenti (dist/site/_nava-<sezione>.scss). Aggiungerne uno = una
# parola qui, poi `scripts/sync_nava_ui.sh <tag>` e l'@import in _includes/style.scss.
PARTS="bento marks-pills-and-legends banner bars profile award code-block-with-a-copy-button"
url() { echo "https://raw.githubusercontent.com/Allan-Nava/nava-ui/$1/dist/tokens.site.scss"; }
part_url() { echo "https://raw.githubusercontent.com/Allan-Nava/nava-ui/$1/dist/site/_nava-$2.scss"; }

case "${1:-}" in
  --check)
    tag="$(head -1 "$TARGET" | grep -o 'nava-ui v[0-9][0-9.]*' | sed 's/nava-ui //')"
    if [ -z "$tag" ]; then
      echo "::error::$TARGET non dichiara la versione del kit nella prima riga"
      exit 1
    fi
    tmp="$(mktemp)"
    curl -fsSL "$(url "$tag")" -o "$tmp"
    if ! diff -u "$tmp" "$TARGET"; then
      echo "::error::$TARGET non e' il file di nava-ui $tag: i token si cambiano nel kit, poi scripts/sync_nava_ui.sh <tag>"
      exit 1
    fi
    echo "ok: $TARGET = nava-ui $tag"
    for part in $PARTS; do
      file="_sass/vendor/_nava-$part.scss"
      curl -fsSL "$(part_url "$tag" "$part")" -o "$tmp"
      if ! diff -u "$tmp" "$file"; then
        echo "::error::$file non e' il file di nava-ui $tag: i componenti si cambiano nel kit, poi scripts/sync_nava_ui.sh <tag>"
        exit 1
      fi
      echo "ok: $file = nava-ui $tag"
    done
    ;;
  v[0-9]*)
    curl -fsSL "$(url "$1")" -o "$TARGET"
    head -1 "$TARGET"
    for part in $PARTS; do
      curl -fsSL "$(part_url "$1" "$part")" -o "_sass/vendor/_nava-$part.scss"
      echo "_sass/vendor/_nava-$part.scss"
    done
    echo "aggiornato $TARGET a nava-ui $1"
    ;;
  *)
    echo "uso: scripts/sync_nava_ui.sh vX.Y.Z | --check" >&2
    exit 2
    ;;
esac
