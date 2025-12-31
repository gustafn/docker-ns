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
build: sync
	$(call run_core,build)
	$(call run_alpine_only,build)

buildx: sync
	$(call run_core,buildx)
	$(call run_alpine_only,buildx)

# ---- per-component convenience ----
build-%: sync
	@if echo "$(ALPINE_ONLY_COMPONENTS)" | tr ' ' '\n' | grep -qx "$*"; then \
	  BASE=alpine; \
	else \
	  BASE="$(BASE)"; \
	fi; \
	printf '==> %b%s%b: build (BASE=%s)\n' "$(BOLD)" "$*" "$(RESET)" "$$BASE"; \
	$(MAKE) -C $* build

buildx-%: sync
	@if echo "$(ALPINE_ONLY_COMPONENTS)" | tr ' ' '\n' | grep -qx "$*"; then \
	  BASE=alpine; \
	else \
	  BASE="$(BASE)"; \
	fi; \
        printf '==> %b%s%b: buildx (BASE=%s)\n' "$(BOLD)" "$*" "$(RESET)" "$$BASE"; \
	$(MAKE) -C $* buildx BASE=alpine; \

clean:
	@set -e; \
	for c in $(CORE_COMPONENTS) $(ALPINE_ONLY_COMPONENTS); do \
	  echo "==> $$c: clean"; \
	  $(MAKE) -C $$c clean; \
	done
.PHONY: help

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
