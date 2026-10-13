#!/usr/bin/env bash
# Run oras: the host's binary when there is one, otherwise the official image with the current
# directory as its working directory. For the image, ORAS_USERNAME and ORAS_PASSWORD log in for
# this one command; the password goes through stdin, never onto a command line.
set -euo pipefail

image="${ORAS_IMAGE:-ghcr.io/oras-project/oras:v1.3.4}"
if command -v oras >/dev/null 2>&1 && [ -z "${ORAS_IN_DOCKER:-}" ]; then
  exec oras "$@"
fi

cmd="${1:?usage: hack/oras.sh <command> [args]}"
shift
run=(docker run --rm -i --network host --user "$(id -u):$(id -g)" -e HOME=/tmp
  -v "$PWD:/work" -w /work "$image" "$cmd")
if [ -n "${ORAS_USERNAME:-}" ]; then
  printf '%s' "${ORAS_PASSWORD:?ORAS_PASSWORD must be set with ORAS_USERNAME}" |
    "${run[@]}" --username "$ORAS_USERNAME" --password-stdin "$@"
else
  "${run[@]}" "$@" </dev/null
fi
