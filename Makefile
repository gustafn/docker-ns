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

.PHONY: all build buildx sync clean 
#        $(addprefix build-,$(CORE_COMPONENTS) $(ALPINE_ONLY_COMPONENTS)) \
#        $(addprefix buildx-,$(CORE_COMPONENTS) $(ALPINE_ONLY_COMPONENTS))

all: build

# ---- shared sync rules ----
sync: openacs/scripts/oacs-db-env.sh munin-node/oacs-db-env.sh \
      naviserver/get-naviserver-modules.sh \
      naviserver-pg/get-naviserver-modules.sh \
      naviserver-oracle/get-naviserver-modules.sh

openacs/scripts/oacs-db-env.sh: scripts/oacs-db-env.sh
	cp -p $< $@
munin-node/oacs-db-env.sh: scripts/oacs-db-env.sh
	cp -p $< $@
NSMOD_TARGETS = \
  naviserver/get-naviserver-modules.sh \
  naviserver-pg/get-naviserver-modules.sh \
  naviserver-oracle/get-naviserver-modules.sh

$(NSMOD_TARGETS): scripts/get-naviserver-modules.sh
	cp -p $< $@

# ---- loop helpers ----
define run_core
	@set -e; \
	for c in $(CORE_COMPONENTS); do \
	  echo "==> $$c: $(1) (BASE=$(BASE))"; \
	  $(MAKE) -C $$c $(1); \
	done
endef

define run_alpine_only
	@set -e; \
	for c in $(ALPINE_ONLY_COMPONENTS); do \
	  echo "==> $$c: $(1) (BASE=alpine)"; \
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
	  echo "==> $*: build (BASE=alpine)"; \
	  $(MAKE) -C $* build BASE=alpine; \
	else \
	  echo "==> $*: build (BASE=$(BASE))"; \
	  $(MAKE) -C $* build; \
	fi

buildx-%: sync
	@if echo "$(ALPINE_ONLY_COMPONENTS)" | tr ' ' '\n' | grep -qx "$*"; then \
	  echo "==> $*: buildx (BASE=alpine)"; \
	  $(MAKE) -C $* buildx BASE=alpine; \
	else \
	  echo "==> $*: buildx (BASE=$(BASE))"; \
	  $(MAKE) -C $* buildx; \
	fi

clean:
	@set -e; \
	for c in $(CORE_COMPONENTS) $(ALPINE_ONLY_COMPONENTS); do \
	  echo "==> $$c: clean"; \
	  $(MAKE) -C $$c clean; \
	done
