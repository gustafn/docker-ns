# SPDX-License-Identifier: MPL-2.0

IMAGE_NAME      = munin-node-openacs

DEFAULT_BASE    ?= alpine
BASE            ?= $(DEFAULT_BASE)

RELEASE_TAG     ?= latest
DOCKER_USERNAME ?= gustafn
PLATFORM        ?= linux/amd64,linux/arm64
LOCAL_TAG       ?=

BASE_SUFFIX := $(if $(filter $(DEFAULT_BASE),$(BASE)),,-$(BASE))
IMAGE       := $(DOCKER_USERNAME)/$(IMAGE_NAME):$(RELEASE_TAG)$(BASE_SUFFIX)$(LOCAL_TAG)
DOCKERFILE  := Dockerfile-$(BASE)


MUNIN_PLUGINS_NS_REPO ?= https://github.com/gustafn/munin-plugins-ns.git
MUNIN_PLUGINS_NS_REF  ?= HEAD
MUNIN_PLUGINS_NS_REV_FILE := .munin-plugins-ns-$(BASE)-$(RELEASE_TAG)$(LOCAL_TAG).rev

$(MUNIN_PLUGINS_NS_REV_FILE):
	@rev=$$(git ls-remote "$(MUNIN_PLUGINS_NS_REPO)" "$(MUNIN_PLUGINS_NS_REF)" | awk '{print $$1}'); \
	if [ -z "$$rev" ]; then \
	  echo "could not resolve $(MUNIN_PLUGINS_NS_REPO) $(MUNIN_PLUGINS_NS_REF)" >&2; \
	  exit 1; \
	fi; \
	if [ ! -f "$@" ] || [ "$$rev" != "$$(cat "$@")" ]; then \
	  echo "$$rev" > "$@"; \
	fi
MUNIN_PLUGINS_NS_REV := $(shell test -f $(MUNIN_PLUGINS_NS_REV_FILE) && cat $(MUNIN_PLUGINS_NS_REV_FILE))

INGREDIENTS = \
  $(DOCKERFILE) \
  Makefile \
  $(wildcard *.sh) \
  $(wildcard *.template) \
  $(MUNIN_PLUGINS_NS_REV_FILE)

STAMP := .built-$(BASE)-$(RELEASE_TAG)$(LOCAL_TAG)
STAMPX := $(STAMP).pushed

# ----------------------------------------------------------------------
# Local build (no push)
# ----------------------------------------------------------------------
build: $(STAMP)
$(STAMP): $(INGREDIENTS)
	docker build --no-cache \
	  --build-arg "RELEASE_TAG=$(RELEASE_TAG)" \
	  --build-arg "MUNIN_PLUGINS_NS_REF=$(MUNIN_PLUGINS_NS_REV)" \
	  -t $(IMAGE) \
	  -f $(DOCKERFILE) .
	touch $@

# ----------------------------------------------------------------------
# Multi-arch build & push using buildx
# ----------------------------------------------------------------------
buildx: $(STAMPX)
$(STAMPX): $(STAMP)
	docker buildx build --push --pull \
	  --platform $(PLATFORM) \
	  --build-arg "RELEASE_TAG=$(RELEASE_TAG)" \
          --build-arg "MUNIN_PLUGINS_NS_REF=$(MUNIN_PLUGINS_NS_REV)" \
	  -t $(IMAGE) \
	  -f $(DOCKERFILE) .
	touch $@

clean:
	rm -f $(STAMP) $(STAMPX)

.PHONY: build buildx clean
