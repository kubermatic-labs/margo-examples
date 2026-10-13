# Go OpenTelemetry Service

An online ordering service that processes a simulated order every few seconds and reports each one
as an OpenTelemetry trace: the span "Ordering app" with "Process Order" and its nine steps, from
"Browse & Select Items" to "Receive Notifications".

The package brings its own backend. Its first component is Jaeger all-in-one with in-memory
storage, the second is the service, which sends its traces to `http://jaeger:4318`. Open the
Jaeger UI on port 16686 and select the service `online-ordering-service`. Every trace carries
`k8s.node.name`, so a fleet shows which device produced it.

To use a collector of your own, point the parameter `otlpEndpoint` at it, and enable
`exportMetrics` if it takes metrics too.

The service is adapted from the test application `custom-otel-helm-app` in the Margo sandbox.
