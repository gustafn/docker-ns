# SPDX-License-Identifier: MPL-2.0

RELEASE_TAG   ?= latest
BASE          ?= alpine
DOCKER_USERNAME ?= gustafn
PLATFORM      ?= linux/amd64,linux/arm64

IMAGE_NAME    = munin-node-openacs
DOCKERFILE    = Dockerfile.$(BASE)
# or Dockerfile.munin-node-$(BASE) if you keep that naming

build:
	docker build \
	  --build-arg "RELEASE_TAG=$(RELEASE_TAG)" \
	  -t $(DOCKER_USERNAME)/$(IMAGE_NAME):$(RELEASE_TAG) \
	  -f $(DOCKERFILE) .

buildx:
	docker buildx build --push \
	  --platform $(PLATFORM) \
	  --build-arg "RELEASE_TAG=$(RELEASE_TAG)" \
	  -t $(DOCKER_USERNAME)/$(IMAGE_NAME):$(RELEASE_TAG) \
	  -f $(DOCKERFILE) .

clean:
	@echo "Nothing to clean for munin-node."

.PHONY: build buildx clean
