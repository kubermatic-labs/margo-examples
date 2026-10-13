#!/usr/bin/env bash
# Run a command in the tools image (LinkML, Python with PyYAML), building the image on first use.
# The examples directory is mounted at /work, read-write, and the command runs as the host user.
#
#   hack/tools.sh linkml validate --schema ... margo.yaml
#   hack/tools.sh python3 hack/margopkg.py check apps/hello-world/package
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(dirname "$here")"
linkml_version="$(sed -n 's/^ARG LINKML_VERSION=//p' "$here/tools.Dockerfile")"
image="margo-examples-tools:linkml-${linkml_version}"

if ! docker image inspect "$image" >/dev/null 2>&1; then
  echo "Building $image (once)..." >&2
  docker build --quiet -t "$image" -f "$here/tools.Dockerfile" "$here" >/dev/null
fi

tty=-i
if [ -t 0 ] && [ -t 1 ]; then tty=-it; fi
exec docker run --rm "$tty" \
  --user "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -v "$root:/work" -w /work \
  "$image" "$@"
