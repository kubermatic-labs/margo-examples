# Hello World

A basic hello world application: a web page with a greeting and the place it runs.

- The deployment's parameters `greeting` and `greetingAddressee` set the greeting.
- The page names the node, pod and namespace, so a fleet demo shows which device answered.
- `GET /api/info` returns the same as JSON, `GET /healthz` is the health check.

This package is the Margo specification's example `ApplicationDescription-001.yaml` from
v1.0.0-rc.3, made deployable: the Kubermatic Margo examples add the chart and the image it
references, and change nothing else. Northstar Industrial Applications is the specification's
fictional vendor.
