#!/usr/bin/env bash
# Render the charts and packages for $REGISTRY into _build/<registry>/:
#   charts/<chart>-<version>.tgz  the charts, their image references pointing at $REGISTRY
#   packages/<app>/               margo.yaml, its chart repositories pointing at $REGISTRY, and resources
# For the canonical registry nothing is rewritten. The rewritten descriptions are validated again.
set -euo pipefail
source "$(dirname "$0")/common.sh"

out="$(build_dir)"
rm -rf "$out"
mkdir -p "$out/charts" "$out/chart-src" "$out/packages"

rewrite() {
  [ "$REGISTRY" = "$CANONICAL_REGISTRY" ] && return 0
  sed -i.bak "s#$CANONICAL_REGISTRY/#$REGISTRY/#g" "$1" && rm -f "$1.bak"
}

for app in $APPS; do
  for chart in "$ROOT/apps/$app/charts"/*/; do
    name="$(basename "$chart")"
    cp -R "$chart" "$out/chart-src/$name"
    rewrite "$out/chart-src/$name/values.yaml"
    "$HELM" package "$out/chart-src/$name" -d "$out/charts" >/dev/null
  done
  cp -R "$ROOT/apps/$app/package" "$out/packages/$app"
  rewrite "$out/packages/$app/margo.yaml"
done
rm -rf "$out/chart-src"

log "built for $REGISTRY in ${out#"$ROOT"/}"
"$HACK/validate.sh" "$out/packages"/*
