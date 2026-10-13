# Cross-compiles on the build host, so a multi-platform build needs no emulation.
FROM --platform=$BUILDPLATFORM golang:1.26 AS build
ARG TARGETOS
ARG TARGETARCH
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-s -w" -o /out/otel-service .

FROM gcr.io/distroless/static:nonroot
COPY --from=build /out/otel-service /otel-service
USER 65532:65532
ENTRYPOINT ["/otel-service"]
