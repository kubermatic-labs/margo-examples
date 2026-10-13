# Node-RED

[Node-RED](https://nodered.org), the low-code flow editor of the OpenJS Foundation, on the edge
device, with an example flow that names the device it runs on.

FLECS Technologies publishes Margo packages for Node-RED, Mosquitto and
COPA-DATA zenon in github.com/FLECS-Technologies/margo-apps, each with a Compose profile for an
earlier Margo draft. This package offers Node-RED with a Helm profile for rc.3 and follows the
parameter choices of FLECS' package. It is an example packaging, not an official Node-RED or
FLECS release, and runs the upstream image `nodered/node-red:4.1.4`.

## What it demonstrates

- Immutable settings: the storage choice is fixed at the first deployment, because switching it
  later would lose the data directory.
- Optional resources from parameters: a PersistentVolumeClaim, a NodePort and the example flow
  appear only when their parameters ask for them.
- A third-party application packaged like the others and offered from the same catalog.

## Parameters

| Parameter           | Default                    | Target                | Validation                    |
| :------------------ | :------------------------- | :-------------------- | :---------------------------- |
| `timezone`          | UTC                        | `timezone`            | IANA time zone name           |
| `flowFile`          | `flows.json`               | `flowFile`            | `<name>.json`                 |
| `nodeOptions`       | `--max-old-space-size=256` | `nodeOptions`         | text, may be empty            |
| `enableProjects`    | false                      | `enableProjects`      | boolean                       |
| `safeMode`          | false                      | `safeMode`            | boolean                       |
| `exampleFlow`       | true                       | `exampleFlow`         | boolean                       |
| `exposeOnDevice`    | false                      | `exposeOnDevice`      | boolean                       |
| `devicePort`        | 31880                      | `devicePort`          | integer, 30000 to 32767       |
| `persistentStorage` | false                      | `persistence.enabled` | boolean, immutable            |
| `storageSize`       | 1Gi                        | `persistence.size`    | `<n>Mi` or `<n>Gi`, immutable |

The editor has no login. `exposeOnDevice=true` opens it on `devicePort` of every node of the
cluster, so set it only where that network is trusted. A NodePort exists once per cluster: two
exposed deployments need two ports.

Without persistent storage the data directory is an emptyDir: flows, credentials and installed
nodes last only as long as the pod. Persistent storage needs a default StorageClass.

FLECS' package also sets `NODE_RED_CREDENTIAL_SECRET`. The Node-RED 4.1.4 image does not read that
variable, so this package leaves it out: Node-RED generates the key and keeps it in the data
directory.

## Demo

```sh
make deploy APP=node-red PARAMS="timezone=Europe/Berlin"
kubectl -n margo-node-red port-forward svc/margo-system-node-red-node-red 1880:1880
```

Open http://localhost:1880: the tab "Margo edge demo" reports a heartbeat with the node name every
10 seconds in the debug sidebar, and http://localhost:1880/hello answers with
`Hello from Node-RED on` and the node name.

## Contents

| Path               | Contents                                                      |
| :----------------- | :------------------------------------------------------------ |
| `charts/node-red/` | Node-RED as user 1000, the example flow in `files/flows.json` |
| `package/`         | `margo.yaml` and its resources                                |
