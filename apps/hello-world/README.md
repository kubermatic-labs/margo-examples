# Hello World

The Margo specification's example application description, `ApplicationDescription-001.yaml` of
v1.0.0-rc.3, made deployable. The chart and image it references exist here, and the description
itself is unchanged except for the chart address.

## What it demonstrates

- A complete package as the specification defines it: metadata, catalog resources, one Helm
  component, parameters with targets and a configuration section with a validation schema.
- Parameters becoming Helm values: `greeting` lands in `global.config.appGreeting` of the
  component `hello-world`.
- Which device answered: the page names the node, pod and namespace it runs in.

## Parameters

| Parameter           | Default | Target                               | Validation                  |
| :------------------ | :------ | :----------------------------------- | :-------------------------- |
| `greeting`          | Hello   | `global.config.appGreeting`          | text, not empty, at most 45 |
| `greetingAddressee` | World   | `global.config.appGreetingAddressee` | text, not empty, at most 45 |

## Demo

```sh
make deploy APP=hello-world PARAMS="greeting=Servus greetingAddressee=Margo"
kubectl -n margo-hello-world port-forward svc/margo-system-hello-world-hello-world 8080:80
```

Open http://localhost:8080: "Servus, Margo!", with the node it runs on. Deploy again with other
parameters and the page follows. `make deploy APP=hello-world PARAMS="greeting="` is rejected
before anything is installed, because the schema does not allow an empty greeting.

`curl -s localhost:8080/api/info` returns the same as JSON.

## Contents

| Path                  | Contents                                                                |
| :-------------------- | :---------------------------------------------------------------------- |
| `app/`                | The web page: Go, standard library only, distroless multi-arch image    |
| `charts/hello-world/` | Chart 1.0.1, image `quay.io/kubermatic-labs/margo-examples/hello-world` |
| `package/`            | `margo.yaml` and its resources                                          |

## Differences from the specification's example

| Field                                                       | Specification                                      | Here                                                              |
| :---------------------------------------------------------- | :------------------------------------------------- | :---------------------------------------------------------------- |
| `deploymentProfiles[0].components[0].properties.repository` | `oci://northstarida.azurecr.io/charts/hello-world` | `oci://quay.io/kubermatic-labs/margo-examples/charts/hello-world` |

Northstar Industrial Applications, its site and its author are the specification's fictional
vendor and stay as they are. The resource files are new: the specification names them but does
not ship them.
