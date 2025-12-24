# SPDX-License-Identifier: MPL-2.0
RELEASE_TAG   ?= latest
BASE          ?= alpine           # we only support alpine here
DOCKER_USERNAME ?= gustafn
PLATFORM      ?= linux/amd64,linux/arm64

IMAGE_NAME    = mail-relay
DOCKERFILE    = Dockerfile.$(BASE)
INGREDIENTS = \
  $(DOCKERFILE) \
  Makefile \
  $(wildcard *.sh) \
  $(wildcard *.template)

IMAGE = $(DOCKER_USERNAME)/$(IMAGE_NAME):$(RELEASE_TAG)-$(BASE)$(LOCAL_TAG)
STAMP = .built-$(BASE)-$(RELEASE_TAG)$(LOCAL_TAG_NORM)

# ----------------------------------------------------------------------
# Local build (no push)
# ----------------------------------------------------------------------
build: $(STAMP)
$(STAMP): $(INGREDIENTS)
	docker build --no-cache \
	  --build-arg "RELEASE_TAG=$(RELEASE_TAG)" \
	  -t $(IMAGE) \
	  -f $(DOCKERFILE) .
	touch $@

# ----------------------------------------------------------------------
# Multi-arch build & push using buildx
# ----------------------------------------------------------------------
buildx: $(STAMP).pushed
$(STAMP).pushed: $(STAMP)
	docker buildx build --push --pull \
	  --platform $(PLATFORM) \
	  --build-arg "RELEASE_TAG=$(RELEASE_TAG)" \
	  -t $(IMAGE) \
	  -f $(DOCKERFILE) .
	touch $@

clean:
	rm -f $(STAMP)

.PHONY: build buildx clean
