#!/usr/bin/env bash
# Check that a deployed app does what its demo promises, in the current kubectl context.
# Reaches the apps through the API server's service proxy, and iaiops through a port-forward,
# which its default allowlist admits. Needs python3 for the JSON.
#   hack/smoke.sh <app>    DEPLOYMENT as for hack/deploy.sh
set -euo pipefail
source "$(dirname "$0")/common.sh"

app="${1:?usage: hack/smoke.sh <app>}"
deployment="${DEPLOYMENT:-$app}"
ns="margo-$deployment"
values_dir="$ROOT/_build/deploy/$deployment"

# value <component> <python expression on v, the component's values>: the deployed setting.
value() {
  python3 -c 'import json, sys; v = json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' \
    "$values_dir/$1.values.json" "$2"
}
service() { "$KUBECTL" -n "$ns" get svc -l "app.kubernetes.io/name=$1" -o jsonpath='{.items[0].metadata.name}'; }
proxy() { "$KUBECTL" get --raw "/api/v1/namespaces/$ns/services/http:$1/proxy$2"; }
ok() { printf '\033[1;32mok\033[0m %s\n' "$*"; }

case "$app" in
hello-world)
  info="$(proxy "$(service hello-world):80" /api/info)"
  expected="$(value hello-world 'v["global"]["config"]["appGreeting"]')"
  python3 - "$info" "$expected" <<'EOF'
import json, sys
info, expected = json.loads(sys.argv[1]), sys.argv[2]
assert info["greeting"] == expected, f"greeting {info['greeting']!r}, expected {expected!r}"
print(f"page says \"{info['greeting']}, {info['addressee']}!\" from node {info['node']}, pod {info['pod']}")
EOF
  ok "hello-world"
  ;;

otel-service)
  name="$(value otel-service 'v["otel"]["serviceName"]')"
  for _ in $(seq 1 30); do
    proxy jaeger:16686 /api/services 2>/dev/null | grep -q "\"$name\"" && break
    sleep 3
  done
  traces="$(proxy jaeger:16686 "/api/traces?service=$name&limit=1&lookback=1h")"
  python3 - "$traces" "$name" <<'EOF'
import json, sys
data, name = json.loads(sys.argv[1])["data"], sys.argv[2]
assert data, f"Jaeger has no trace of {name}"
trace = data[0]
spans = {s["operationName"] for s in trace["spans"]}
tags = {t["key"]: t["value"] for p in trace["processes"].values() for t in p.get("tags", [])}
assert {"Ordering app", "Process Order", "Receive Notifications"} <= spans, spans
assert tags.get("k8s.node.name"), f"no k8s.node.name in {tags}"
print(f"Jaeger has trace {trace['traceID'][:12]}.. of {name}: {len(trace['spans'])} spans, from node {tags['k8s.node.name']}")
EOF
  ok "otel-service"
  ;;

iaiops)
  svc="$(service iaiops)"
  port="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
  "$KUBECTL" -n "$ns" port-forward "svc/$svc" "$port:mcp" >/dev/null 2>&1 &
  pf=$!
  trap 'kill "$pf" 2>/dev/null || true' EXIT
  for _ in $(seq 1 30); do
    curl -s -o /dev/null "http://127.0.0.1:$port/" && break
    sleep 1
  done
  url="http://127.0.0.1:$port/mcp"
  python3 "$HACK/mcp_call.py" "$url" tools | grep -qx modbus_health_summary ||
    die "iaiops offers no modbus_health_summary tool"
  for snapshot in 1 2; do
    [ "$snapshot" = 1 ] || sleep 3
    python3 "$HACK/mcp_call.py" "$url" modbus_health_summary '{"endpoint": "line1"}' |
      python3 -c '
import json, sys
s = json.load(sys.stdin)
assert s["evaluated"] == 3, s
v = {r["label"]: int(r["value"]) for r in s["results"]}
state = {0: "stopped", 1: "idle", 2: "running", 3: "fault"}.get(v["Line run state"], "?")
total, good = v["Production counter"], v["Good-parts counter"]
print(f"line1 {state}: {total} parts, {good} good")'
  done
  ok "iaiops reads line1 over Modbus through its MCP tools"
  ;;

node-red)
  svc="$(service node-red)"
  if [ "$(value node-red 'v["exampleFlow"]')" = True ]; then
    answer="$(proxy "$svc:1880" /hello)"
    case "$answer" in "Hello from Node-RED on "*) echo "$answer" ;; *) die "GET /hello answered: $answer" ;; esac
  else
    proxy "$svc:1880" / | grep -q '<title>Node-RED</title>' || die "no Node-RED editor"
  fi
  ok "node-red"
  ;;

*) die "unknown app $app" ;;
esac
