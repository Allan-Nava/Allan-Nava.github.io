#!/usr/bin/env bash
# Il sito legge i design token da nava-ui (https://github.com/Allan-Nava/nava-ui), il kit
# estratto da questo sito: la copia sta in _sass/vendor/_nava-tokens.scss ed e' il file
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
url() { echo "https://raw.githubusercontent.com/Allan-Nava/nava-ui/$1/dist/tokens.site.scss"; }

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
    ;;
  v[0-9]*)
    curl -fsSL "$(url "$1")" -o "$TARGET"
    head -1 "$TARGET"
    echo "aggiornato $TARGET a nava-ui $1"
    ;;
  *)
    echo "uso: scripts/sync_nava_ui.sh vX.Y.Z | --check" >&2
    exit 2
    ;;
esac
