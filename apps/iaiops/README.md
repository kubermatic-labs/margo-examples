# Industrial-AIOps

[Industrial-AIOps](https://github.com/industrial-aiops/industrial-aiops) (iaiops) reads OT devices
over their field protocols, read-first, and offers what it reads as governed MCP tools: audited,
risk-tiered, with the few writes gated. This package runs it on the edge device next to a
simulated production line, so an AI assistant can ask about that line right after the deployment.

It is an example packaging, not an official iaiops release. iaiops publishes its own Margo
package with a Compose profile for an earlier Margo draft; this one adds a Helm profile for rc.3
and runs the upstream image `ghcr.io/industrial-aiops/iaiops:0.28.0-<edition>`.

## What it demonstrates

- AI at the edge on OT data: an MCP client reaches the line's run state and part counters through
  iaiops' tools, without any OT protocol on the client side.
- A select parameter (the edition, which also picks the image), a double (the ideal cycle time)
  and a boolean that switches a whole component off.
- A component that serves another: `line-simulator` comes first, with `wait`, and iaiops reads it
  as endpoint `line1` at `line-simulator:5020`.

## Parameters

| Parameter        | Default          | Target                                   | Validation                             |
| :--------------- | :--------------- | :--------------------------------------- | :------------------------------------- |
| `profile`        | factory          | `profile` of iaiops                      | factory, fab, process, building, water |
| `allowlistIps`   | `127.0.0.1/32`   | `mcp.allowlist` of iaiops                | comma-separated CIDRs                  |
| `modbusHost`     | `line-simulator` | `modbus.host` of iaiops                  | host name or IP address                |
| `modbusPort`     | 5020             | `modbus.port` of iaiops                  | integer, 1 to 65535                    |
| `idealCycleTime` | 0.1              | `modbus.idealCycleTimeSeconds` of iaiops | seconds per part, 0.001 to 3600        |
| `lineSimulator`  | true             | `enabled` of line-simulator              | boolean                                |
| `shiftSeconds`   | 300              | `shiftSeconds` of line-simulator         | integer, 60 to 86400                   |

The MCP server listens on port 8000 and answers only clients in `allowlistIps`. A
`kubectl port-forward` connects from 127.0.0.1, which the default admits.

## Demo

```sh
make deploy APP=iaiops
kubectl -n margo-iaiops port-forward svc/margo-system-iaiops-iaiops 8000:8000
```

Connect an MCP client to `http://127.0.0.1:8000/mcp`, for example Claude Code:

```sh
claude mcp add --transport http iaiops http://127.0.0.1:8000/mcp
```

and ask:

- "What state is line1 in, and how many parts has it made?"
- "Sample line1 every 10 seconds for two minutes, then compute its OEE with an ideal cycle time
  of 0.1 seconds."

Without an assistant, `hack/mcp_call.py` calls a tool directly:

```sh
python3 hack/mcp_call.py http://127.0.0.1:8000/mcp modbus_health_summary '{"endpoint": "line1"}'
```

The simulated shift lasts `shiftSeconds` and repeats: running, two minor stops, an idle period
and a long fault, with about one part in 25 scrapped.

## Reading a real line

```sh
make deploy APP=iaiops PARAMS="lineSimulator=false modbusHost=192.0.2.10 modbusPort=502"
```

The tag layout stays that of the demo line: run state in holding register 0 (2 means running),
production counter in 10, good parts in 11. Modbus has no authentication, so keep the device on a
segment only the edge cluster reaches.

## Contents

| Path                         | Contents                                                                         |
| :--------------------------- | :------------------------------------------------------------------------------- |
| `line-simulator/`            | The Modbus TCP line, from the iaiops OEE demo, see its README                    |
| `charts/oee-line-simulator/` | The simulator, image `quay.io/kubermatic-labs/margo-examples/oee-line-simulator` |
| `charts/iaiops/`             | iaiops over streamable HTTP, read-only root file system, non-root                |
| `package/`                   | `margo.yaml` and its resources                                                   |
