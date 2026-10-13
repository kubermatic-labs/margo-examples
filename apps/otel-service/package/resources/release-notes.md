# Release notes

## 0.1.0

- First release of the package, built on the Margo sandbox application `custom-otel-helm-app`.
- New: the component `jaeger`, so the traces have a place to go on the device.
- New: the parameters `serviceName`, `exportMetrics` and `orderInterval`.
- The service adds `OTEL_RESOURCE_ATTRIBUTES` to its resource and flushes its spans on shutdown.
- Multi-arch image (amd64, arm64) on a distroless base.
