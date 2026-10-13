#!/usr/bin/env bash
# Publish what hack/build.sh rendered for $REGISTRY: the images, the charts and the Margo packages.
#
#   PLATFORMS  image platforms, default linux/amd64,linux/arm64
#   ONLY       images, charts or packages, to publish one kind only
#
# The logins are yours: `docker login` for the images, which Helm also uses for the charts, and a
# host `oras login` or ORAS_USERNAME/ORAS_PASSWORD for the packages.
set -euo pipefail
source "$(dirname "$0")/common.sh"

out="$(build_dir)"
[ -d "$out/packages" ] || die "nothing built for $REGISTRY, run hack/build.sh first"
platforms="${PLATFORMS:-linux/amd64,linux/arm64}"
only="${ONLY:-}"
want() { [ -z "$only" ] || [ "$only" = "$1" ]; }

if want images; then
  while read -r name context chart; do
    [ -n "$name" ] || continue
    version="$(chart_field "$ROOT/$chart" appVersion)"
    log "image $REGISTRY/$name:$version for $platforms"
    docker buildx build --quiet --platform "$platforms" --build-arg "VERSION=$version" \
      --tag "$REGISTRY/$name:$version" --push "$ROOT/$context" >/dev/null
  done <<<"$IMAGES"
fi

if want charts; then
  for tgz in "$out/charts"/*.tgz; do
    log "chart oci://$REGISTRY/charts/$(basename "$tgz" .tgz)"
    # shellcheck disable=SC2046 # empty or one flag
    "$HELM" push "$tgz" "oci://$REGISTRY/charts" $(helm_plain_http) >/dev/null
  done
fi

if want packages; then
  for app in $APPS; do
    pkg="$out/packages/$app"
    rel="${pkg#"$ROOT"/}"
    ref="$REGISTRY/packages/$app:$(margopkg version "$rel" </dev/null)"
    files=()
    while IFS= read -r f; do files+=("$f"); done < <(margopkg push-files "$rel" </dev/null)
    margopkg push-annotations "$rel" </dev/null >"$pkg/.annotations.json"
    log "package $ref"
    # shellcheck disable=SC2046 # empty or one flag
    (cd "$pkg" && "$HACK/oras.sh" push $(helm_plain_http) \
      --artifact-type application/vnd.margo.app.v1+json \
      --annotation-file .annotations.json "$ref" "${files[@]}" >/dev/null)
    rm -f "$pkg/.annotations.json"
  done
fi
