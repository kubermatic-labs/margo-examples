#!/usr/bin/env bash
# Render the package resources that are not plain text, with headless Chrome:
# the icons (256x256 PNG, transparent corners) and the Hello World license PDF.
# The sources are in hack/resources/; the output goes to each app's package/resources/.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
src="$here/resources"
apps="$(cd "$here/../apps" && pwd)"
chrome="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
[ -x "$chrome" ] || chrome="$(command -v google-chrome || command -v chromium || true)"
[ -n "$chrome" ] || { echo "Chrome not found, set CHROME" >&2; exit 1; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

icon() { # <svg> <png>
  printf '<!doctype html><html><body style="margin:0;background:transparent">%s</body></html>' "$(cat "$1")" > "$tmp/icon.html"
  "$chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --default-background-color=00000000 --window-size=256,256 \
    --screenshot="$2" "file://$tmp/icon.html" >/dev/null 2>&1
  echo "rendered ${2#"$apps"/}"
}

pdf() { # <html> <pdf>
  "$chrome" --headless=new --disable-gpu --no-pdf-header-footer \
    --print-to-pdf="$2" "file://$1" >/dev/null 2>&1
  echo "rendered ${2#"$apps"/}"
}

icon "$src/hello-world.svg"  "$apps/hello-world/package/resources/hw-logo.png"
icon "$src/otel-service.svg" "$apps/otel-service/package/resources/otel-service.png"
icon "$src/iaiops.svg"       "$apps/iaiops/package/resources/iaiops.png"
icon "$src/node-red.svg"     "$apps/node-red/package/resources/node-red.png"
pdf  "$src/hello-world-license.html" "$apps/hello-world/package/resources/license.pdf"
