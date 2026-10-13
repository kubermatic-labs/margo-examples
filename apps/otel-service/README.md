# Go OpenTelemetry Service

An online ordering service that reports every order as an OpenTelemetry trace, packaged with
Jaeger so the traces can be looked at on the device. It is the test application
`custom-otel-helm-app` from the Margo sandbox, made into a package that deploys as it is.

## What it demonstrates

- Two components in profile order: `jaeger` first, with `wait`, then `otel-service`, which sends
  its traces to `http://jaeger:4318` in the same namespace.
- Eligibility rules: the profile asks for a device whose capabilities list `helm` among its
  deployment types and `oci` among its runtimes.
- Traces that name the device: every trace carries `k8s.node.name` and `k8s.pod.name`.
- Text with a pattern, boolean and integer parameters.

## Parameters

| Parameter       | Default                   | Target                               | Validation                  |
| :-------------- | :------------------------ | :----------------------------------- | :-------------------------- |
| `otlpEndpoint`  | `http://jaeger:4318`      | `otel.endpoint` of otel-service      | http(s) URL                 |
| `serviceName`   | `online-ordering-service` | `otel.serviceName` of otel-service   | lower-case name, at most 63 |
| `exportMetrics` | false                     | `otel.exportMetrics` of otel-service | boolean                     |
| `orderInterval` | 5                         | `orderInterval` of otel-service      | integer seconds, 1 to 3600  |

Jaeger takes traces only, so metrics are off by default. Point `otlpEndpoint` at an OpenTelemetry
Collector and set `exportMetrics=true` to get the counter `orders_processed` as well.

## Demo

```sh
make deploy APP=otel-service
kubectl -n margo-otel-service port-forward svc/jaeger 16686:16686
```

Open http://localhost:16686, pick the service `online-ordering-service` and find traces: each has
the span "Ordering app" with "Process Order" and its nine steps. The process tags show the node
that produced it.

Change the workload and look again:

```sh
make deploy APP=otel-service PARAMS="serviceName=orders-line-2 orderInterval=1"
```

## Contents

| Path                   | Contents                                                                 |
| :--------------------- | :----------------------------------------------------------------------- |
| `app/`                 | The service, adapted from the sandbox, in a distroless multi-arch image  |
| `charts/jaeger/`       | Jaeger 2.13.0 all-in-one: OTLP in, in-memory storage, UI on 16686        |
| `charts/otel-service/` | The service, image `quay.io/kubermatic-labs/margo-examples/otel-service` |
| `package/`             | `margo.yaml` and its resources                                           |

## Changes compared to the sandbox

The sandbox application is at `poc/tests/artefacts/custom-otel-helm-app` in
github.com/margo/sandbox, commit `a54bbfd2a704e6dee9f36fc97c8a004ff1afa005`.

- **Code:** `OTEL_SERVICE_NAME` and `OTEL_RESOURCE_ATTRIBUTES` reach the trace resource,
  `OTEL_METRICS_EXPORTER=none` turns the metrics off, `ORDER_INTERVAL_SECONDS` sets the pace, and
  SIGTERM flushes the pending spans and metrics. Span names and timings are unchanged.
- **Image:** a multi-stage build into `gcr.io/distroless/static:nonroot` for amd64 and arm64,
  instead of the Go toolchain image.
- **Chart:** new. It has no Service, since the application listens on nothing, and fills the
  resource attributes from the downward API.
- **`jaeger` component:** new, so the traces have a place to go on the device.
- **`margo.yaml`:** valid for rc.3. `timeout: 5m0s` instead of `5m`, parameter targets that name
  the component instead of the profile, chart addresses instead of `{{HELM_REPOSITORY}}`, resource
  files that exist, amd64 and arm64, and requirements sized for the two containers. The
  eligibility rules are the sandbox's.
