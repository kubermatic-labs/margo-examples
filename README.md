# Margo example applications

Four applications packaged for [Margo](https://margo.org) v1.0.0-rc.3, with the tooling to
validate, publish and deploy them. They show what a Margo application package contains, how a
workload fleet manager turns one into workloads on an edge device, and what each application can
demonstrate there.

| App                               | Package id                         | Version | Components             | What it demonstrates                                                    |
| :-------------------------------- | :--------------------------------- | :------ | :--------------------- | :---------------------------------------------------------------------- |
| [hello-world](apps/hello-world)   | `com-northstartida-hello-world`    | 1.0     | hello-world            | The specification's own example, made deployable                        |
| [otel-service](apps/otel-service) | `com-go-otel-service`              | 0.1.0   | jaeger, otel-service   | Ordered components, eligibility rules, traces that name the device      |
| [iaiops](apps/iaiops)             | `com-kubermatic-examples-iaiops`   | 0.28.0  | line-simulator, iaiops | AI assistants reading OT data through MCP, select and double parameters |
| [node-red](apps/node-red)         | `com-kubermatic-examples-node-red` | 4.1.4   | node-red               | Node-RED as FLECS packages it, immutable settings, optional storage     |

Every package uses one Helm deployment profile and runs on amd64 and arm64.

## The flow

```text
build              publish to an OCI registry               workload fleet manager        edge device
-----              --------------------------               ----------------------        -----------
images        -->  <registry>/<image>:<version>         \
charts        -->  oci://<registry>/charts/<chart>       >  pull, validate, render  -->  namespace margo-<deployment>,
margo.yaml    -->  <registry>/packages/<app>:<version>  /   values, install in order      one Helm release per component
```

1. **Build.** `make build` packages the charts and the Margo packages for one registry.
2. **Publish.** `make publish` pushes the images (multi-arch), the charts and the packages. A package
   is one OCI artifact per version, as the Margo application registry defines it: artifact type
   `application/vnd.margo.app.v1+json`, an empty config, `margo.yaml` and the resource files as
   layers, and the tag equal to `metadata.version`.
3. **Catalog.** A workload fleet manager lists the package versions in the registry and shows the
   application in its catalog. In Kubermatic's fleet manager,
   [margo-management](https://github.com/kubermatic-labs/margo-management), this is the change
   `add-margo-application-catalog`.
4. **Deploy.** The fleet manager pulls the package, validates the deployment's parameters against
   the package's configuration schema, writes them into each component's Helm values and installs
   the components in profile order. In margo-management this is the change
   `add-margo-application-deployment`.

Until those changes ship, `make deploy` performs step 4 against any kubectl context, with the
names the design uses: namespace `margo-<deployment>`, release `margo-system-<deployment>-<component>`.

## Quick start on your machine

Needs Docker with buildx, kind, kubectl, Helm 3.13 or later, python3 and curl. The schema
validation (LinkML) and the package pushes (oras) run in containers.

```sh
make e2e
```

This validates the packages, lints the charts, starts a local registry on `localhost:5001` and a
kind cluster `margo-examples` that pulls from it, publishes everything there for the Docker host's
platform, deploys all four apps and checks each one. It takes a few minutes, most of it pulling
the Node-RED, iaiops and Jaeger images.

Then run the demos against the kind cluster:

```sh
export KUBECONFIG=$PWD/_build/kind.kubeconfig REGISTRY=localhost:5001/margo-examples
make deploy APP=hello-world PARAMS="greeting=Servus greetingAddressee=Margo"
kubectl -n margo-hello-world port-forward svc/margo-system-hello-world-hello-world 8080:80
```

Each app's README has its demo. `make kind-down` removes the cluster and the registry.

## Deploy to an edge cluster

Point `KUBECONFIG` at the edge cluster and deploy from a registry the cluster can pull from:

```sh
KUBECONFIG=edge.kubeconfig make deploy APP=otel-service PARAMS="orderInterval=10"
KUBECONFIG=edge.kubeconfig make smoke APP=otel-service
KUBECONFIG=edge.kubeconfig make undeploy APP=otel-service
```

`REGISTRY` defaults to `quay.io/toschneck/margo-examples`, where the packages are published for
now. `DEPLOYMENT=<name>` deploys the same app a second time under another name.

## Demo environment

`demo/` holds the environment of the margo-management demo, in which the operator creates an edge
cluster, joins a machine and deploys a package
([guide](https://github.com/kubermatic-labs/margo-management/blob/main/docs/margo/demo-e2e.md)):

- `margo-e2e.clustertemplate.yaml`: the KKP ClusterTemplate of the edge clusters, applied on the KKP
  master;
- `kubevirt-test-vm.yaml`: the KubeVirt VM `test-edge-prov`, the machine that joins them.

## Publish

```sh
docker login quay.io                         # Helm uses this login for the charts too
export ORAS_USERNAME=... ORAS_PASSWORD=...   # or install oras and run oras login
make publish
```

The sources name `quay.io/kubermatic-labs/margo-examples`. For any other registry `make build`
rewrites that prefix in the chart values and in `margo.yaml`, so images, charts and packages always
come from the same place. quay.io creates the repositories on the first push as private ones: make
them public, so that clusters and fleet managers pull without credentials.

## Rules the packages follow

- **Helm charts the fleet manager can own.** No hooks, no `lookup`, no CRDs and no cluster-scoped
  objects: a second deployment of the same package, in its own namespace, must not collide with
  the first. `make check-charts` renders every component with the values its parameters produce
  and enforces this.
- **No node selectors.** Placement on one machine is the fleet manager's job: margo-management
  pins a deployment with a namespace node selector.
- **Fixed names between components.** A component that another one calls keeps a fixed Service
  name (`jaeger`, `line-simulator`), because release names belong to the fleet manager.
- **Parameters are the only interface.** Each `targets[].pointer` is a Helm `--set` path into the
  component's values, and every parameter has a validation schema.

## Layout

| Path                                 | Contents                                                                       |
| :----------------------------------- | :----------------------------------------------------------------------------- |
| `apps/<app>/package/`                | `margo.yaml` and its resource files: icon, description, release notes, license |
| `apps/<app>/charts/<chart>/`         | The Helm charts the package's components reference                             |
| `apps/<app>/app/`, `line-simulator/` | Sources and Dockerfiles of the images built here                               |
| `hack/margo-schema/v1.0.0-rc.3/`     | The Margo ApplicationDescription schema, unchanged, with its provenance        |
| `hack/margopkg.py`                   | Package checks, parameter rendering and the chart rules                        |
| `hack/*.sh`                          | Build, publish, deploy, smoke and kind scripts behind the Makefile             |
| `hack/resources/`                    | Sources of the icons and of the Hello World license PDF                        |
| `demo/`                              | The KKP ClusterTemplate and the KubeVirt test VM of the margo-management demo  |

## Sources and licenses

| Part                                          | Source                                                    | License                                     |
| :-------------------------------------------- | :-------------------------------------------------------- | :------------------------------------------ |
| hello-world `margo.yaml`                      | Margo specification, `ApplicationDescription-001.yaml`    | Open Web Foundation CLA Copyright Grant 0.9 |
| otel-service application, adapted             | Margo sandbox, `poc/tests/artefacts/custom-otel-helm-app` | Open Web Foundation CLA Copyright Grant 0.9 |
| `apps/iaiops/line-simulator/simulate_line.py` | industrial-aiops/industrial-aiops v0.28.0                 | MIT, see `LICENSE.iaiops`                   |
| Margo schema in `hack/margo-schema/`          | Margo specification v1.0.0-rc.3                           | Open Web Foundation CLA Copyright Grant 0.9 |
| Everything else in this repository            | Kubermatic                                                | Apache License 2.0, see `LICENSE`           |

The upstream images (`jaegertracing/jaeger`, `ghcr.io/industrial-aiops/iaiops`,
`nodered/node-red`) are referenced, not redistributed. The Node-RED parameters follow the
choices of FLECS Technologies' Margo package for Node-RED, in this repository's own wording.
