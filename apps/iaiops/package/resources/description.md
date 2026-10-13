# Industrial-AIOps

[Industrial-AIOps](https://github.com/industrial-aiops/industrial-aiops) (iaiops) reads OT
devices over their field protocols, read-first, and offers what it reads as governed MCP tools:
every call is audited and risk-tiered, and the few writes are gated. An AI assistant connected
over MCP can ask for live values, downtime events and OEE.

This package deploys two components:

1. `line-simulator`: a Modbus TCP production line built from the iaiops OEE demo. It cycles
   through running, minor stops, idle time and a long fault, and counts good and scrapped parts.
2. `iaiops`: the MCP server over streamable HTTP on port 8000, configured to read the line as
   endpoint `line1`, with tag roles for run state, total count and good count.

Connect an MCP client through `kubectl port-forward`, which the default allowlist admits, and ask
for example: "What is the OEE of line1 over the last minutes?"

To read a real line, disable the simulator and set the Modbus host and port. Modbus has no
authentication, so keep the device on a segment that only the edge cluster reaches.

This is an example packaging by the Kubermatic Margo examples, not an official iaiops release.
It runs the upstream image `ghcr.io/industrial-aiops/iaiops:0.28.0-<edition>`.
