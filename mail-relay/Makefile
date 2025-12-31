# SPDX-License-Identifier: MPL-2.0

IMAGE_NAME    = mail-relay

DEFAULT_BASE ?= alpine
BASE ?= $(DEFAULT_BASE)   # we only support alpine here

RELEASE_TAG     ?= latest
DOCKER_USERNAME ?= gustafn
PLATFORM        ?= linux/amd64,linux/arm64
LOCAL_TAG       ?=

BASE_SUFFIX := $(if $(filter $(DEFAULT_BASE),$(BASE)),,-$(BASE))
IMAGE       := $(DOCKER_USERNAME)/$(IMAGE_NAME):$(RELEASE_TAG)$(BASE_SUFFIX)$(LOCAL_TAG)
DOCKERFILE  := Dockerfile-$(BASE)

INGREDIENTS = \
  $(DOCKERFILE) \
  Makefile \
  $(wildcard *.sh) \
  $(wildcard *.template)

STAMP := .built-$(BASE)-$(RELEASE_TAG)$(LOCAL_TAG)

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
