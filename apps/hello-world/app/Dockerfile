# Cross-compiles on the build host, so a multi-platform build needs no emulation.
FROM --platform=$BUILDPLATFORM golang:1.26 AS build
ARG TARGETOS
ARG TARGETARCH
ARG VERSION=dev
WORKDIR /src
COPY go.mod ./
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-s -w -X main.version=${VERSION}" -o /out/hello-world .

FROM gcr.io/distroless/static:nonroot
COPY --from=build /out/hello-world /hello-world
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/hello-world"]
