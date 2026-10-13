#!/usr/bin/env bash
# Lint every chart and check the rules of the Margo service on what it renders: no hooks, no
# `lookup`, no CRDs, no cluster-scoped objects. Each component is rendered with the values its
# package's parameters produce: the defaults, plus the parameter sets below.
set -euo pipefail
source "$(dirname "$0")/common.sh"

# Further parameter sets per app, one per line, to render the optional paths too.
extra_params() {
  case "$1" in
    otel-service) echo "exportMetrics=true orderInterval=30" ;;
    iaiops)       echo "lineSimulator=false modbusHost=10.0.0.5 modbusPort=502 profile=water" ;;
    node-red)     echo "exposeOnDevice=true persistentStorage=true exampleFlow=false safeMode=true" ;;
  esac
}

mkdir -p "$ROOT/_build"
values="$ROOT/_build/values.json"
manifests="$ROOT/_build/manifests.yaml"
trap 'rm -f "$values" "$manifests"' EXIT

failed=0
for app in $APPS; do
  pkg="apps/$app/package"
  sets=("")
  while IFS= read -r line; do [ -n "$line" ] && sets+=("$line"); done < <(extra_params "$app")
  components=()
  while IFS= read -r line; do components+=("$line"); done < <(margopkg components "$pkg" </dev/null)

  for entry in "${components[@]}"; do
    IFS=$'\t' read -r component repository revision _ <<<"$entry"
    chart="apps/$app/charts/${repository##*/}"
    if ! "$HELM" lint --quiet "$ROOT/$chart" >/dev/null; then
      "$HELM" lint "$ROOT/$chart" >&2 || true
      failed=1
    fi
    for params in "${sets[@]}"; do
      # shellcheck disable=SC2086 # params is a list of name=value words
      if margopkg values "$pkg" "$component" $params >"$values" </dev/null &&
        "$HELM" template "margo-system-$app-$component" "$ROOT/$chart" -n "margo-$app" -f "$values" >"$manifests" &&
        margopkg chart-rules "$chart" <"$manifests"; then
        echo "$chart $revision: ok${params:+ with $params}"
      else
        echo "$chart $revision: FAILED${params:+ with $params}" >&2
        failed=1
      fi
    done
  done
done
exit "$failed"
