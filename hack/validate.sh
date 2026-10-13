#!/usr/bin/env bash
# Validate Margo packages: the rc.3 LinkML schema, then the checks the schema cannot express
# (resource files, parameter targets, settings, chart versions, default values).
#
#   hack/validate.sh                 every app in apps/
#   hack/validate.sh <package-dir>   e.g. a built package under _build/
set -euo pipefail
source "$(dirname "$0")/common.sh"

schema="hack/margo-schema/v1.0.0-rc.3/application-description.linkml.yaml"
if [ $# -eq 0 ]; then
  set --
  for app in $APPS; do set -- "$@" "apps/$app/package"; done
  semantic=1
else
  semantic=0
fi

failed=0
for pkg in "$@"; do
  rel="${pkg#"$ROOT"/}"
  out="$(tools linkml validate --schema "$schema" --target-class ApplicationDescription "$rel/margo.yaml" 2>&1)" || true
  if [ "$(printf '%s\n' "$out" | tail -1)" = "No issues found" ]; then
    echo "$rel/margo.yaml: valid against Margo v1.0.0-rc.3"
  else
    printf '%s\n' "$out" >&2
    echo "$rel/margo.yaml: INVALID" >&2
    failed=1
  fi
done
if [ "$semantic" = 1 ]; then
  pkgs=()
  for app in $APPS; do pkgs+=("apps/$app/package"); done
  margopkg check "${pkgs[@]}" || failed=1
fi
exit "$failed"
