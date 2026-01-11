# SPDX-License-Identifier: MPL-2.0
IMAGE_NAME ?= naviserver-oracle
SYSTEM_PKGS ?=

DEFAULT_BASE ?= trixie
BASE ?= $(DEFAULT_BASE)
RELEASE_TAG ?= latest
LOCAL_TAG ?=
ALIAS_TAG ?=
BASE_STAMP ?=

VERSION_NS ?= GIT
DOCKER_USERNAME ?= gustafn
DOCKER_PROGRESS ?= plain
PLATFORM ?= linux/amd64,linux/arm64

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

# Normalized platform strings for stamps/tags
PLATFORM_AMD64 ?= linux/amd64
PLATFORM_ARM64 ?= linux/arm64

# Internal per-arch tags (used only to assemble the multi-arch manifest)
IMAGE_AMD64 = $(IMAGE)-amd64
IMAGE_ARM64 = $(IMAGE)-arm64
REFRESH_PLATFORMS ?= $(PLATFORM_AMD64)

# Optional: force no-cache per platform (e.g., NOCACHE_AMD64=1)
NOCACHE_AMD64 ?= 0
NOCACHE_ARM64 ?= 0
BUILDX_NOCACHE_AMD64 := $(if $(filter 1,$(NOCACHE_AMD64)),--no-cache,)
BUILDX_NOCACHE_ARM64 := $(if $(filter 1,$(NOCACHE_ARM64)),--no-cache,)

# Stamps for per-arch buildx and final manifest assembly
STAMP_BUILDX_AMD64 := .builtx-amd64-$(BASE)-$(RELEASE_TAG)-$(VERSION_NS_NORM)-nc$(NOCACHE_AMD64)
STAMP_BUILDX_ARM64 := .builtx-arm64-$(BASE)-$(RELEASE_TAG)-$(VERSION_NS_NORM)-nc$(NOCACHE_ARM64)
STAMP_BUILDX_MANIFEST := .builtx-manifest-$(BASE)-$(RELEASE_TAG)-$(VERSION_NS_NORM)
STAMP_BUILDX_LEGACY := .builtx-$(BASE)-$(RELEASE_TAG)-$(VERSION_NS_NORM)
STAMP := .built-$(BASE)-$(RELEASE_TAG)-$(VERSION_NS_NORM)$(LOCAL_TAG_NORM)


INGREDIENTS = \
  $(DOCKERFILE) \
  Makefile \
  $(wildcard scripts/*) \
  $(wildcard initdb/*) \
  $(wildcard install/*) \
  $(wildcard *.sh) \
  $(BASE_STAMP)

.PHONY: build buildx clean

define refresh_tag
	@echo "==> Refresh local image $(1) from registry ($(REFRESH_PLATFORMS))"
	@docker rmi -f $(1) >/dev/null 2>&1 || true
	@set -e; for p in $(REFRESH_PLATFORMS); do \
	  echo "    pulling $$p ..."; \
	  docker pull --platform $$p $(1) >/dev/null; \
	done
endef

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
# Multi-arch build & push using buildx (per-arch + manifest assembly)
# ----------------------------------------------------------------------
buildx: buildx-amd64 buildx-arm64 buildx-manifest

buildx-amd64: $(STAMP_BUILDX_AMD64)
$(STAMP_BUILDX_AMD64): $(INGREDIENTS)
	@if [ -n "$(LOCAL_TAG)" ]; then \
	  echo "ERROR: refusing to push with LOCAL_TAG=$(LOCAL_TAG)"; exit 2; \
	fi
	docker buildx build --push --pull --platform $(PLATFORM_AMD64) \
	  $(BUILDX_NOCACHE_AMD64) \
	  --progress=$(DOCKER_PROGRESS) \
	  --build-arg "RELEASE_TAG=$(RELEASE_TAG)" \
	  --build-arg "version_ns=$(VERSION_NS)" \
	  --build-arg "system_pkgs=$(SYSTEM_PKGS)" \
	  -t $(IMAGE_AMD64) \
	  -f $(DOCKERFILE) \
	  .
	touch $@

buildx-arm64: $(STAMP_BUILDX_ARM64)
$(STAMP_BUILDX_ARM64): $(INGREDIENTS)
	@if [ -n "$(LOCAL_TAG)" ]; then \
	  echo "ERROR: refusing to push with LOCAL_TAG=$(LOCAL_TAG)"; exit 2; \
	fi
	docker buildx build --push --pull --platform $(PLATFORM_ARM64) \
	  $(BUILDX_NOCACHE_ARM64) \
	  --progress=$(DOCKER_PROGRESS) \
	  --build-arg "RELEASE_TAG=$(RELEASE_TAG)" \
	  --build-arg "version_ns=$(VERSION_NS)" \
	  --build-arg "system_pkgs=$(SYSTEM_PKGS)" \
	  -t $(IMAGE_ARM64) \
	  -f $(DOCKERFILE) \
	  .
	touch $@

buildx-manifest: $(STAMP_BUILDX_MANIFEST)
$(STAMP_BUILDX_MANIFEST): $(STAMP_BUILDX_AMD64) $(STAMP_BUILDX_ARM64)
	@if [ -n "$(LOCAL_TAG)" ]; then \
	  echo "ERROR: refusing to push with LOCAL_TAG=$(LOCAL_TAG)"; exit 2; \
	fi
	# Assemble final multi-arch tag from per-arch tags
	docker buildx imagetools create -t $(IMAGE) $(IMAGE_AMD64) $(IMAGE_ARM64)
ifneq ($(strip $(ALIAS_TAG)),)
	docker buildx imagetools create -t $(IMAGE_ALIAS) $(IMAGE_AMD64) $(IMAGE_ARM64)
endif
	$(call refresh_tag,$(IMAGE))
ifneq ($(strip $(ALIAS_TAG)),)
	$(call refresh_tag,$(IMAGE_ALIAS))
endif
	touch $@

# ----------------------------------------------------------------------
# Force Multi-arch build & push using buildx
# ----------------------------------------------------------------------
.PHONY: buildx-force
buildx-force:
	rm -f $(STAMP)
	$(MAKE) buildx

clean:
	rm -f $(STAMP) $(STAMP).pushed $(STAMP).pushed-* \
	      .builtx-amd64-$(BASE)-$(RELEASE_TAG)-$(VERSION_NS_NORM)-nc* \
	      .builtx-arm64-$(BASE)-$(RELEASE_TAG)-$(VERSION_NS_NORM)-nc* \
	      $(STAMP_BUILDX_MANIFEST) \
	      .builtx-$(BASE)-$(RELEASE_TAG)-$(VERSION_NS_NORM)

#
# Local Variables:
# mode: makefile
# End:
#

