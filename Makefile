# Margo example applications: validate, build, publish and deploy them. `make help` lists the targets.

# Where images, charts and packages are published and pulled from. A personal namespace for now,
# until the packages move to the registry the sources name (CANONICAL_REGISTRY in hack/common.sh).
REGISTRY ?= quay.io/toschneck/margo-examples
# The registry of `make e2e`, a registry:2 container next to the kind cluster.
LOCAL_REGISTRY ?= localhost:5001/margo-examples
# Image platforms for `make publish`. `make e2e` builds the Docker host's platform only.
PLATFORMS ?= linux/amd64,linux/arm64
APP ?=
PARAMS ?=
DEPLOYMENT ?=

HELM ?= helm
KUBECTL ?= kubectl
KIND ?= kind
export REGISTRY PLATFORMS DEPLOYMENT HELM KUBECTL KIND

APPS := hello-world otel-service iaiops node-red
KIND_KUBECONFIG := $(CURDIR)/_build/kind.kubeconfig
NATIVE_PLATFORM = linux/$(shell docker version --format '{{.Server.Arch}}')

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "} /^##@/ {printf "\n%s\n", substr($$0, 5)} /^[a-z0-9-]+:.*## / {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

##@ Check

.PHONY: validate
validate: ## Validate the packages against Margo v1.0.0-rc.3 and their own rules
	hack/validate.sh

.PHONY: check-charts
check-charts: ## Lint the charts and check the Margo chart rules on what they render
	hack/check-charts.sh

.PHONY: check
check: validate check-charts ## validate and check-charts

##@ Build and publish

.PHONY: build
build: ## Render charts and packages for REGISTRY into _build/
	hack/build.sh

.PHONY: publish
publish: build ## Push images (PLATFORMS), charts and packages to REGISTRY
	hack/publish.sh

##@ Deploy, into the current kubectl context

.PHONY: deploy
deploy: ## Deploy APP from REGISTRY like a fleet manager would, PARAMS="name=value ..."
	@test -n "$(APP)" || { echo "set APP to one of: $(APPS)"; exit 1; }
	hack/deploy.sh $(APP) $(PARAMS)

.PHONY: smoke
smoke: ## Check that the deployed APP does what its demo promises
	@test -n "$(APP)" || { echo "set APP to one of: $(APPS)"; exit 1; }
	hack/smoke.sh $(APP)

.PHONY: undeploy
undeploy: ## Remove the deployed APP and its namespace
	@test -n "$(APP)" || { echo "set APP to one of: $(APPS)"; exit 1; }
	hack/undeploy.sh $(APP)

##@ Local edge

.PHONY: kind-up
kind-up: ## Start a local registry and a kind cluster that pulls from it
	hack/kind.sh up

.PHONY: kind-down
kind-down: ## Delete the kind cluster and the local registry
	hack/kind.sh down

.PHONY: e2e
e2e: check kind-up ## Check, publish to the local registry, deploy every app on kind and smoke-test it
	$(MAKE) publish REGISTRY=$(LOCAL_REGISTRY) PLATFORMS=$(NATIVE_PLATFORM)
	@set -e; for app in $(APPS); do \
	  KUBECONFIG=$(KIND_KUBECONFIG) REGISTRY=$(LOCAL_REGISTRY) hack/deploy.sh $$app; \
	  KUBECONFIG=$(KIND_KUBECONFIG) REGISTRY=$(LOCAL_REGISTRY) hack/smoke.sh $$app; \
	done

.PHONY: clean
clean: ## Remove _build/
	rm -rf _build
