#!/bin/sh
# Atualiza os candles diários a partir da API pública de dados da Binance
# (data-api.binance.vision, sem chave) e regenera index.html.
#
# Uso:  scripts/update-data.sh                 # pares padrão: BTCUSDT ETHUSDT SOLUSDT
#       scripts/update-data.sh BTCUSDT XRPUSDT # outros pares (todo o histórico se o arquivo não existir)
#
# Formato de cada arquivo data/<PAR>.json: [[dia,open,high,low,close], ...]
# dia = dias desde 1970-01-01 (UTC). O candle do dia corrente (ainda aberto) é descartado.
# Requer curl e jq.
set -eu
cd "$(dirname "$0")/.."

PAIRS="${*:-BTCUSDT ETHUSDT SOLUSDT}"
API="https://data-api.binance.vision/api/v3/klines"
TODAY=$(( $(date -u +%s) / 86400 ))
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

for P in $PAIRS; do
  FILE="data/$P.json"
  if [ -f "$FILE" ]; then
    LAST=$(jq '.[-1][0]' "$FILE")
  else
    LAST=-1
    echo "[]" > "$TMP/old.json"
  fi
  [ -f "$FILE" ] && cp "$FILE" "$TMP/old.json"

  echo "$P: último dia salvo = $LAST, buscando novos candles..."
  END=$(( TODAY * 86400 * 1000 - 1 ))   # fim de ontem (UTC), em ms: exclui o candle do dia corrente
  echo "[]" > "$TMP/new.json"
  PAGE=0
  while :; do
    PAGE=$((PAGE + 1))
    URL="$API?symbol=$P&interval=1d&limit=1000&endTime=$END"
    curl -fsS --retry 3 --retry-delay 2 "$URL" > "$TMP/page.json" || { echo "Falha ao baixar $P" >&2; exit 1; }
    N=$(jq 'length' "$TMP/page.json")
    [ "$N" -eq 0 ] && break
    # [ms,"o","h","l","c",...] -> [dia,o,h,l,c]
    jq '[.[] | [(.[0]/86400000|floor), (.[1]|tonumber), (.[2]|tonumber), (.[3]|tonumber), (.[4]|tonumber)]]' \
      "$TMP/page.json" > "$TMP/conv.json"
    jq -s '.[0] + .[1]' "$TMP/conv.json" "$TMP/new.json" > "$TMP/acc.json" && mv "$TMP/acc.json" "$TMP/new.json"
    FIRST=$(jq '.[0][0]' "$TMP/conv.json")
    # Já cobrimos o último dia salvo, ou a página veio incompleta (início do histórico)
    if [ "$FIRST" -le "$LAST" ] || [ "$N" -lt 1000 ]; then break; fi
    END=$(( FIRST * 86400 * 1000 - 1 ))
    [ "$PAGE" -ge 50 ] && { echo "Paginação excedeu 50 páginas" >&2; exit 1; }
  done

  # Mescla: candles novos substituem os antigos do mesmo dia; ordena; remove dia corrente por segurança
  jq -c -s --argjson today "$TODAY" \
    '(.[0] + .[1]) | group_by(.[0]) | map(.[-1]) | map(select(.[0] < $today)) | sort_by(.[0])' \
    "$TMP/old.json" "$TMP/new.json" > "$TMP/merged.json"
  ADDED=$(( $(jq length "$TMP/merged.json") - $(jq length "$TMP/old.json") ))
  mv "$TMP/merged.json" "$FILE"
  echo "$P: $(jq length "$FILE") candles (+$ADDED), até o dia $(jq '.[-1][0]' "$FILE")"
done

# data/all.json com todos os data/*.json existentes
jq -c -n 'reduce inputs as $x ({}; . + {($x.k): $x.v})' \
  $(for f in data/*.json; do [ "$f" = data/all.json ] && continue; \
      n=$(basename "$f" .json); jq -c --arg k "$n" '{k:$k, v:.}' "$f" > "$TMP/$n.kv"; echo "$TMP/$n.kv"; done) \
  > "$TMP/all.json"
mv "$TMP/all.json" data/all.json

sh scripts/build.sh
