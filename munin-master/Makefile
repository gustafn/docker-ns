# SPDX-License-Identifier: MPL-2.0

# Default settings – override on the command line if needed, e.g.:
#   make build RELEASE_TAG=dev
#   make buildx RELEASE_TAG=2024-12-07
RELEASE_TAG     ?= latest
BASE            ?= alpine
DOCKER_USERNAME ?= gustafn
PLATFORM        ?= linux/amd64,linux/arm64

# Docker Hub image name: DOCKER_USERNAME/IMAGE_NAME:TAG
# Change IMAGE_NAME here if you want a different repo name.
IMAGE_NAME      ?= munin-master

# We currently only support an Alpine Dockerfile:
DOCKERFILE      = Dockerfile.$(BASE)

# ----------------------------------------------------------------------
# Local build (no push)
# ----------------------------------------------------------------------
build:
	docker build \
	  --build-arg "RELEASE_TAG=$(RELEASE_TAG)" \
	  -t $(DOCKER_USERNAME)/$(IMAGE_NAME):$(RELEASE_TAG) \
	  -f $(DOCKERFILE) .

# ----------------------------------------------------------------------
# Multi-arch build & push using buildx
# ----------------------------------------------------------------------
buildx:
	docker buildx build \
	  --platform $(PLATFORM) \
	  --build-arg "RELEASE_TAG=$(RELEASE_TAG)" \
	  -t $(DOCKER_USERNAME)/$(IMAGE_NAME):$(RELEASE_TAG) \
	  -f $(DOCKERFILE) \
	  --push .

# ----------------------------------------------------------------------
# Convenience targets
# ----------------------------------------------------------------------
tag-latest:
	docker tag $(DOCKER_USERNAME)/$(IMAGE_NAME):$(RELEASE_TAG) \
	           $(DOCKER_USERNAME)/$(IMAGE_NAME):latest

clean:
	@echo "Nothing to clean (no local artifacts)."

.PHONY: build buildx tag-latest clean
