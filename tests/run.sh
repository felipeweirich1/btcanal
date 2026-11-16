#!/bin/sh
# Runs the engine tests on macOS: extracts the engine from index.html (from <script> up to the
# render section) and runs it with tests/engine.test.js through osascript (JavaScript for Automation).
# Usage: sh tests/run.sh   (run sh scripts/build.sh first if you changed src/template.html)
set -eu
cd "$(dirname "$0")/.."
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
awk '/^<script>/{f=1;next} /render ----------/{exit} f' index.html > "$TMP/engine.js"
{
  echo "(function(){"
  cat "$TMP/engine.js"
  sed '$d' tests/engine.test.js
  printf "return %s\n" "$(tail -n 1 tests/engine.test.js | sed "s/;\$//")"
  echo "})()"
} > "$TMP/run.js"
OUT=$(osascript -l JavaScript "$TMP/run.js")
echo "$OUT"
echo "$OUT" | grep -q "^FALHA" && exit 1 || exit 0
