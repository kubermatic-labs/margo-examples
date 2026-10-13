# Node-RED

[Node-RED](https://nodered.org) is a low-code programming tool for event-driven applications.
Its browser-based editor wires together hardware devices, APIs and online services as flows, with
a large library of community nodes for industrial protocols.

This package runs the upstream image `nodered/node-red:4.1.4` and seeds an example flow:

- a heartbeat every 10 seconds that reports the node and pod it runs on, in the debug sidebar;
- `GET /hello`, which answers with the node name.

Open the editor through `kubectl port-forward` on port 1880. The editor has no login: expose it on
the device's network only where that network is trusted.

Without persistent storage the data directory is an emptyDir, so flows, credentials and installed
nodes last only as long as the pod. Persistent storage needs a default StorageClass on the device.

The parameter set follows FLECS Technologies' Margo package for Node-RED. This is an example
packaging by the Kubermatic Margo examples, not an official Node-RED or FLECS release.
