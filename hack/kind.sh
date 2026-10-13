#!/usr/bin/env bash
# A local stand-in for an edge device: a kind cluster that pulls images from a local registry.
#
#   hack/kind.sh up     registry container on localhost:5001, then the cluster
#   hack/kind.sh down   delete both
#
# The kubeconfig goes to _build/kind.kubeconfig, so your current kubectl context stays as it is.
set -euo pipefail
source "$(dirname "$0")/common.sh"

KIND="${KIND:-kind}"
cluster="${KIND_CLUSTER:-margo-examples}"
registry="${LOCAL_REGISTRY_NAME:-margo-examples-registry}"
port="${LOCAL_REGISTRY_PORT:-5001}"
kubeconfig="$ROOT/_build/kind.kubeconfig"

up() {
  if [ "$(docker inspect -f '{{.State.Running}}' "$registry" 2>/dev/null)" != true ]; then
    log "registry $registry on localhost:$port"
    docker rm -f -v "$registry" >/dev/null 2>&1 || true
    docker run -d --restart=always -p "127.0.0.1:$port:5000" --name "$registry" registry:2 >/dev/null
  fi
  mkdir -p "$ROOT/_build"
  if ! "$KIND" get clusters 2>/dev/null | grep -qx "$cluster"; then
    log "kind cluster $cluster"
    "$KIND" create cluster --name "$cluster" --kubeconfig "$kubeconfig" --config=- <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry]
      config_path = "/etc/containerd/certs.d"
EOF
  else
    "$KIND" export kubeconfig --name "$cluster" --kubeconfig "$kubeconfig" >/dev/null 2>&1
  fi
  # Inside the nodes, localhost:<port> is the registry container on the kind network.
  for node in $("$KIND" get nodes --name "$cluster"); do
    docker exec "$node" mkdir -p "/etc/containerd/certs.d/localhost:$port"
    printf '[host."http://%s:5000"]\n' "$registry" |
      docker exec -i "$node" cp /dev/stdin "/etc/containerd/certs.d/localhost:$port/hosts.toml"
  done
  docker network connect kind "$registry" 2>/dev/null || true
  log "ready: export KUBECONFIG=$kubeconfig"
}

down() {
  "$KIND" delete cluster --name "$cluster" --kubeconfig "$kubeconfig" 2>/dev/null || true
  docker rm -f -v "$registry" >/dev/null 2>&1 || true
  rm -f "$kubeconfig"
}

case "${1:-}" in
up) up ;;
down) down ;;
*) die "usage: hack/kind.sh up|down" ;;
esac
