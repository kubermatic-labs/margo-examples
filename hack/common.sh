# Shared settings for the scripts in hack/. Sourced, not run.
# shellcheck shell=bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HACK="$ROOT/hack"

# The registry the sources name. A build for another registry rewrites this prefix in the chart
# values and in margo.yaml, so images, charts and packages always come from the same place.
CANONICAL_REGISTRY="quay.io/kubermatic-labs/margo-examples"
# Published to a personal namespace for now, like the Makefile's default.
REGISTRY="${REGISTRY:-quay.io/toschneck/margo-examples}"

APPS="hello-world otel-service iaiops node-red"

# Images built from this repository: name, build context, chart whose appVersion is the tag.
IMAGES="
hello-world        apps/hello-world/app       apps/hello-world/charts/hello-world
otel-service       apps/otel-service/app      apps/otel-service/charts/otel-service
oee-line-simulator apps/iaiops/line-simulator apps/iaiops/charts/oee-line-simulator
"

HELM="${HELM:-helm}"
KUBECTL="${KUBECTL:-kubectl}"

# _build/<registry with / and : replaced>, so builds for two registries never mix.
build_dir() { echo "$ROOT/_build/$(echo "$REGISTRY" | tr '/:' '__')"; }

# A registry on this machine speaks plain HTTP.
is_local_registry() { case "$REGISTRY" in localhost:* | localhost/* | 127.0.0.1:* | 127.0.0.1/*) return 0 ;; esac; return 1; }
helm_plain_http() { if is_local_registry; then echo "--plain-http"; fi; }

# chart_field <chart-dir> <version|appVersion>
chart_field() { sed -n "s/^$2: *\"\{0,1\}\([^\"]*\)\"\{0,1\} *$/\1/p" "$1/Chart.yaml"; }

# Helm release of a component, as KKP names it for the ApplicationInstallation
# <deployment>-<component> in margo-system: that name is shortened above 40 characters.
release_name() {
  local name="$1-$2" sum
  if [ "${#name}" -gt 40 ]; then
    sum="$(printf '%s' "$name" | { sha256sum 2>/dev/null || shasum -a 256; } | cut -c1-8)"
    name="${name:0:31}-$sum"
  fi
  echo "margo-system-$name"
}

tools() { "$HACK/tools.sh" "$@"; }
margopkg() { tools python3 hack/margopkg.py "$@"; }

log() { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
