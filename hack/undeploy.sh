#!/usr/bin/env bash
# Remove a deployment made by hack/deploy.sh: its components in reverse profile order, then its
# namespace.
#   hack/undeploy.sh <app>    DEPLOYMENT as for hack/deploy.sh
set -euo pipefail
source "$(dirname "$0")/common.sh"

app="${1:?usage: hack/undeploy.sh <app>}"
deployment="${DEPLOYMENT:-$app}"
namespace="margo-$deployment"

components=""
while IFS=$'\t' read -r component _; do
  components="$component $components"
done < <(margopkg components "apps/$app/package" </dev/null)
for component in $components; do
  release="$(release_name "$deployment" "$component")"
  log "uninstall $release"
  "$HELM" uninstall "$release" --namespace "$namespace" --ignore-not-found --wait >/dev/null
done
"$KUBECTL" delete namespace "$namespace" --ignore-not-found --wait=true
