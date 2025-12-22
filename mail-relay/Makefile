# SPDX-License-Identifier: MPL-2.0
RELEASE_TAG   ?= latest
BASE          ?= alpine           # we only support alpine here
DOCKER_USERNAME ?= gustafn
PLATFORM      ?= linux/amd64,linux/arm64

IMAGE_NAME    = mail-relay
DOCKERFILE    = Dockerfile.$(BASE)

# In our case: Dockerfile.alpine
# If you keep the name Dockerfile.mail-relay-alpine, adjust:
# DOCKERFILE = Dockerfile.mail-relay-$(BASE)

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
	@echo "Nothing to clean for mail-relay (no local artifacts)."

.PHONY: build buildx clean
