#!/usr/bin/env bash
# Deploy an app the way a workload fleet manager does, into the current kubectl context:
#  1. pull its Margo package from $REGISTRY and validate it;
#  2. turn the parameters into Helm values for every component, validated against the package's
#     configuration schema, before anything is installed;
#  3. install the Helm components in profile order, each waiting when the package says so.
# Names follow the margo-management deployment design: namespace margo-<deployment>, release
# margo-system-<deployment>-<component>.
#
#   hack/deploy.sh <app> [name=value ...]
#   DEPLOYMENT  name of the deployment, default <app>
#   VERSION     package version, default the one in apps/<app>/package/margo.yaml
set -euo pipefail
source "$(dirname "$0")/common.sh"

app="${1:?usage: hack/deploy.sh <app> [name=value ...]}"
shift
deployment="${DEPLOYMENT:-$app}"
namespace="margo-$deployment"
version="${VERSION:-$(margopkg version "apps/$app/package" </dev/null)}"
ref="$REGISTRY/packages/$app:$version"
work="$ROOT/_build/deploy/$deployment"
rel="${work#"$ROOT"/}"
rm -rf "$work"
mkdir -p "$work/package"

log "pull $ref"
# shellcheck disable=SC2046 # empty or one flag
(cd "$work/package" && "$HACK/oras.sh" pull $(helm_plain_http) "$ref" >/dev/null)
"$HACK/validate.sh" "$work/package" >/dev/null || die "$ref is not a valid Margo package"

components=()
while IFS= read -r line; do components+=("$line"); done < <(margopkg components "$rel/package" </dev/null)
for entry in "${components[@]}"; do
  IFS=$'\t' read -r component _ <<<"$entry"
  margopkg values "$rel/package" "$component" "$@" >"$work/$component.values.json" </dev/null ||
    die "parameters rejected, nothing was installed"
done

log "deploy $app $version as $deployment into $namespace, context $("$KUBECTL" config current-context)"
for entry in "${components[@]}"; do
  IFS=$'\t' read -r component repository revision wait timeout <<<"$entry"
  release="$(release_name "$deployment" "$component")"
  wait_args=()
  if [ "$wait" = true ]; then wait_args=(--wait --timeout "${timeout:-5m0s}"); fi
  log "  $component: $repository $revision as release $release${wait_args:+, waiting}"
  # shellcheck disable=SC2046 # empty or one flag
  "$HELM" upgrade --install "$release" "$repository" --version "$revision" \
    --namespace "$namespace" --create-namespace -f "$work/$component.values.json" \
    ${wait_args[@]+"${wait_args[@]}"} $(helm_plain_http) >/dev/null
done
log "deployed; check it with: make smoke APP=$app${DEPLOYMENT:+ DEPLOYMENT=$deployment}"
