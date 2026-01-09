# SPDX-License-Identifier: MPL-2.0

BASE ?= trixie
RELEASE_TAG ?= latest
VERSION_NS ?= GIT
DOCKER_USERNAME ?= gustafn
DOCKER_PROGRESS ?= plain
PLATFORM ?= linux/amd64,linux/arm64
SYSTEM_PKGS ?=
LOCAL_TAG ?=

export BASE RELEASE_TAG VERSION_NS DOCKER_USERNAME DOCKER_PROGRESS PLATFORM SYSTEM_PKGS LOCAL_TAG

VERSION_NS_NORM := $(if $(strip $(VERSION_NS)),$(VERSION_NS),default)
LOCAL_TAG_NORM  := $(if $(strip $(LOCAL_TAG)),$(LOCAL_TAG),)

STAMP_BUILD      := .built-$(BASE)-$(RELEASE_TAG)-$(VERSION_NS_NORM)$(LOCAL_TAG_NORM)
STAMP_BUILDX_MAN := .builtx-manifest-$(BASE)-$(RELEASE_TAG)-$(VERSION_NS_NORM)

CORE_COMPONENTS = \
	naviserver \
	naviserver-pg \
	naviserver-oracle \
	openacs

ALPINE_ONLY_COMPONENTS = \
	munin-master \
	munin-node \
	mail-relay

BOLD  := \033[1m
RESET := \033[0m

.PHONY: all build buildx sync clean help
#        $(addprefix build-,$(CORE_COMPONENTS) $(ALPINE_ONLY_COMPONENTS)) \
#        $(addprefix buildx-,$(CORE_COMPONENTS) $(ALPINE_ONLY_COMPONENTS))

all: build

# ---- shared sync rules ----
sync: openacs/scripts/oacs-db-env.sh \
	munin-node/oacs-db-env.sh \
	naviserver/get-naviserver-modules.sh \
	naviserver-pg/get-naviserver-modules.sh \
	naviserver-oracle/get-naviserver-modules.sh \
	openacs/scripts/get-naviserver-modules.sh

openacs/scripts/oacs-db-env.sh: scripts/oacs-db-env.sh
	cp -p $< $@
munin-node/oacs-db-env.sh: scripts/oacs-db-env.sh
	cp -p $< $@
NSMOD_TARGETS = \
  naviserver/get-naviserver-modules.sh \
  naviserver-pg/get-naviserver-modules.sh \
  naviserver-oracle/get-naviserver-modules.sh \
  openacs/scripts/get-naviserver-modules.sh

$(NSMOD_TARGETS): scripts/get-naviserver-modules.sh
	cp -p $< $@


# ----------------------------------------------------------------------
# Stamp dependency chain (core images)
# ----------------------------------------------------------------------

# naviserver has no base dependency
naviserver/$(STAMP_BUILD): sync
	$(MAKE) -C naviserver build

naviserver/$(STAMP_BUILDX_MAN): sync
	$(MAKE) -C naviserver buildx

# naviserver-pg depends on naviserver
naviserver-pg/$(STAMP_BUILD): naviserver/$(STAMP_BUILD) sync
	$(MAKE) -C naviserver-pg build

naviserver-pg/$(STAMP_BUILDX_MAN): naviserver/$(STAMP_BUILDX_MAN) sync
	$(MAKE) -C naviserver-pg buildx

# naviserver-oracle depends on naviserver
naviserver-oracle/$(STAMP_BUILD): naviserver/$(STAMP_BUILD) sync
	$(MAKE) -C naviserver-oracle build

naviserver-oracle/$(STAMP_BUILDX_MAN): naviserver/$(STAMP_BUILDX_MAN) sync
	$(MAKE) -C naviserver-oracle buildx

# openacs depends on naviserver-pg
openacs/$(STAMP_BUILD): naviserver-pg/$(STAMP_BUILD) sync
	$(MAKE) -C openacs build

openacs/$(STAMP_BUILDX_MAN): naviserver-pg/$(STAMP_BUILDX_MAN) sync
	$(MAKE) -C openacs buildx

# ---- loop helpers ----
define run_core
	@set -e; \
	for c in $(CORE_COMPONENTS); do \
          printf '==> %b%s%b: $(1) (BASE=$(BASE))\n' "$(BOLD)" "$$c" "$(RESET)"; \
	  $(MAKE) -C $$c $(1); \
	done
endef

define run_alpine_only
	@set -e; \
	for c in $(ALPINE_ONLY_COMPONENTS); do \
          printf '==> %b%s%b: $(1) (BASE=$(BASE))\n' "$(BOLD)" "$$c" "$(RESET)"; \
	  $(MAKE) -C $$c $(1) BASE=alpine; \
	done
endef

# ---- main targets ----
build:  naviserver/$(STAMP_BUILD) naviserver-pg/$(STAMP_BUILD) naviserver-oracle/$(STAMP_BUILD) openacs/$(STAMP_BUILD)
	$(call run_alpine_only,build)

buildx: naviserver/$(STAMP_BUILDX_MAN) naviserver-pg/$(STAMP_BUILDX_MAN) naviserver-oracle/$(STAMP_BUILDX_MAN) openacs/$(STAMP_BUILDX_MAN)
	$(call run_alpine_only,buildx)

# ---- per-component convenience ----
build-%: sync
	@if echo "$(ALPINE_ONLY_COMPONENTS)" | tr ' ' '\n' | grep -qx "$*"; then \
	  BASE=alpine; \
	else \
	  BASE="$(BASE)"; \
	fi; \
	printf '==> %b%s%b: build (BASE=%s)\n' "$(BOLD)" "$*" "$(RESET)" "$$BASE"; \
	$(MAKE) -C $* build BASE="$$BASE"

buildx-%: sync
	@if echo "$(ALPINE_ONLY_COMPONENTS)" | tr ' ' '\n' | grep -qx "$*"; then \
	  BASE=alpine; \
	else \
	  BASE="$(BASE)"; \
	fi; \
	printf '==> %b%s%b: buildx (BASE=%s)\n' "$(BOLD)" "$*" "$(RESET)" "$$BASE"; \
	$(MAKE) -C $* buildx BASE="$$BASE"

clean:
	@set -e; \
	for c in $(CORE_COMPONENTS) $(ALPINE_ONLY_COMPONENTS); do \
	  echo "==> $$c: clean"; \
	  $(MAKE) -C $$c clean; \
	done

rebuild: clean build
rebuildx: clean buildx

help:
	@printf "%s\n" "docker-ns Makefile targets"
	@printf "%s\n" "========================="
	@printf "\n%s\n" "Common:"
	@printf "  %-28s %s\n" "make" "Build all images locally (no push)"
	@printf "  %-28s %s\n" "make help" "Show this help"
	@printf "\n%s\n" "Local builds (recommended when you changed files in this repo):"
	@printf "  %-28s %s\n" "make build-naviserver" "Build NaviServer image locally"
	@printf "  %-28s %s\n" "make build-openacs" "Build OpenACS image locally"
	@printf "  %-28s %s\n" "make build-mail-relay" "Build mail-relay image locally"
	@printf "  %-28s %s\n" "make build-munin-node" "Build munin-node image locally"
	@printf "  %-28s %s\n" "make build-munin-master" "Build munin-master image locally"
	@printf "\n%s\n" "Using -local tags:"
	@printf "  %-28s %s\n" "make LOCAL_TAG=-local build-openacs" "Build as ...:latest-local (no push)"
	@printf "  %-28s %s\n" "make LOCAL_TAG=-local" "Build all as ...:latest-local (no push)"
	@printf "\n%s\n" "Multi-arch builds (buildx) – builds AND pushes to Docker Hub:"
	@printf "  %-28s %s\n" "make buildx-openacs" "Multi-arch build + push OpenACS image"
	@printf "  %-28s %s\n" "make buildx-TARGET" "Same tags as with: make build-TARGET"
	@printf "\n%s\n" "Versioned builds (examples):"
	@printf "  %-28s %s\n" "make VERSION_NS=5.0.3 RELEASE_TAG=5.0.3 build" "Local versioned build"
	@printf "  %-28s %s\n" "make VERSION_NS=5.0.3 RELEASE_TAG=5.0.3 buildx-openacs" "Multi-arch versioned build + push"
	@printf "\n%s\n" "Variables:"
	@printf "  %-28s %s\n" "LOCAL_TAG=-local" "Append suffix to image tags (e.g. :latest-local)"
	@printf "  %-28s %s\n" "RELEASE_TAG=<tag>" "Image tag to build (e.g. 5.0.3, latest)"
	@printf "  %-28s %s\n" "VERSION_NS=<ver>" "NaviServer version (used by some images/builds)"
	@printf "\n%s\n" "Notes:"
	@printf "  %s\n" "- buildx targets require docker login + push rights to the Docker Hub repo."
	@printf "  %s\n" "- If you modified files locally, prefer LOCAL_TAG=-local and reference that tag"
	@printf "  %s\n" "  (e.g. gustafn/openacs:latest-local) in docker-compose."


.PHONY: help rebuild
