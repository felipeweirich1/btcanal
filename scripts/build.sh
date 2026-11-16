#!/bin/sh
# Gera index.html (raiz do repositório, servido pelo GitHub Pages) a partir de
# src/template.html, embutindo data/all.json no marcador /*DATA*/.
# Requer apenas perl.
set -eu
cd "$(dirname "$0")/.."

[ -f data/all.json ] || { echo "data/all.json não encontrado. Rode scripts/update-data.sh." >&2; exit 1; }
grep -q '/\*DATA\*/' src/template.html || { echo "Marcador /*DATA*/ ausente em src/template.html" >&2; exit 1; }

perl -0pe 'BEGIN{local $/; open F,"<","data/all.json" or die; $d=<F>; chomp $d;} s#/\*DATA\*/#$d#' \
  src/template.html > index.html.tmp
mv index.html.tmp index.html
echo "index.html gerado ($(wc -c < index.html | tr -d ' ') bytes)"
