# SPDX-License-Identifier: MPL-2.0
IMAGE_NAME ?= naviserver-oracle

DEFAULT_BASE ?= trixie
BASE ?= $(DEFAULT_BASE)
RELEASE_TAG ?= latest
LOCAL_TAG ?=
ALIAS_TAG ?=

VERSION_NS ?= GIT
DOCKER_USERNAME ?= gustafn
DOCKER_PROGRESS ?= plain
PLATFORM ?= linux/amd64,linux/arm64
SYSTEM_PKGS ?=

IMAGE = $(DOCKER_USERNAME)/$(IMAGE_NAME):$(RELEASE_TAG)-$(BASE)$(LOCAL_TAG)
DOCKERFILE = Dockerfile-$(BASE)

# If BASE is equal to DEFAULT_BASE, and ALIAS_TAG is empty, set it automatically
ifeq ($(strip $(ALIAS_TAG)),)
  ifeq ($(BASE),$(DEFAULT_BASE))
    ifeq ($(LOCAL_TAG),)
      ALIAS_TAG := $(RELEASE_TAG)
    endif
  endif
endif

# Only form IMAGE_ALIAS if ALIAS_TAG is set (non-empty)
ifneq ($(strip $(ALIAS_TAG)),)
IMAGE_ALIAS = $(DOCKER_USERNAME)/$(IMAGE_NAME):$(ALIAS_TAG)
ALIAS_TAG_OPT = -t $(IMAGE_ALIAS)
else
ALIAS_TAG_OPT =
endif

VERSION_NS_NORM := $(if $(strip $(VERSION_NS)),$(VERSION_NS),default)
LOCAL_TAG_NORM  := $(if $(strip $(LOCAL_TAG)),$(LOCAL_TAG),)

#STAMP = $(IMAGE_NAME).built
# stamp encodes variant
#STAMP = .built-$(BASE)-$(RELEASE_TAG)$(LOCAL_TAG_NORM)
STAMP = .built-$(BASE)-$(RELEASE_TAG)-$(VERSION_NS_NORM)$(LOCAL_TAG_NORM)

INGREDIENTS = \
  $(DOCKERFILE) \
  Makefile \
  $(wildcard scripts/*) \
  $(wildcard initdb/*) \
  $(wildcard install/*) \
  $(wildcard *.sh) \

.PHONY: build buildx clean

# ----------------------------------------------------------------------
# Local build (no push)
# ----------------------------------------------------------------------
build: $(STAMP)
$(STAMP): $(INGREDIENTS)
	docker build --no-cache \
	  --progress=$(DOCKER_PROGRESS) \
	  --build-arg "RELEASE_TAG=$(RELEASE_TAG)" \
	  --build-arg "LOCAL_TAG=$(LOCAL_TAG)" \
	  --build-arg "version_ns=$(VERSION_NS)" \
	  --build-arg "system_pkgs=$(SYSTEM_PKGS)" \
	  -t $(IMAGE) \
	  -f $(DOCKERFILE) \
	  .
ifneq ($(strip $(ALIAS_TAG)),)
	# Do not accidentally overwrite shared tags with local builds:
	@if [ -n "$(LOCAL_TAG)" ]; then \
	  echo "INFO: LOCAL_TAG is set ($(LOCAL_TAG)); skipping alias tag $(IMAGE_ALIAS)"; \
	else \
	  docker tag $(IMAGE) $(IMAGE_ALIAS); \
	fi
endif
	touch $@

# ----------------------------------------------------------------------
# Multi-arch build & push using buildx
# ----------------------------------------------------------------------
buildx: $(STAMP).pushed
$(STAMP).pushed: $(STAMP)
	@if [ -n "$(LOCAL_TAG)" ]; then \
	  echo "ERROR: refusing to push with LOCAL_TAG=$(LOCAL_TAG)"; exit 2; \
	fi
	docker buildx build --push --pull --platform $(PLATFORM) \
	  --progress=$(DOCKER_PROGRESS) \
	  --build-arg "RELEASE_TAG=$(RELEASE_TAG)" \
	  --build-arg "version_ns=$(VERSION_NS)" \
	  --build-arg "system_pkgs=$(SYSTEM_PKGS)" \
	  -t $(IMAGE) $(ALIAS_TAG_OPT) \
	  -f $(DOCKERFILE) \
	  .
	touch $@

# ----------------------------------------------------------------------
# Force Multi-arch build & push using buildx
# ----------------------------------------------------------------------
.PHONY: buildx-force
buildx-force:
	rm -f $(STAMP)
	$(MAKE) buildx

clean:
	rm -f $(STAMP)

