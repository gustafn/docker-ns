#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# get-docker-config.sh
#
# Fetch the full Docker container JSON for *this* container and write it to
# /scripts/docker.config, owned by nsadmin:nsadmin (mode 640).
#
# Requirements:
#   - /var/run/docker.sock mounted into the container
#   - Classic Docker storage layout that exposes the container ID in
#     /proc/self/mountinfo as /docker/containers/<64hex>/...
#

# HOSTNAME is expected to be set by the container runtime.
# shellcheck disable=SC3028
: "${HOSTNAME:?}"

set -e

CONFIG_PATH="/scripts/docker.config"

# 1) Derive container ID from /proc/self/mountinfo
CID=$(
  grep -Eo '/docker/containers/[0-9a-f]{64}' /proc/self/mountinfo 2>/dev/null \
    | sed 's#.*/##' \
    | head -n1
)

# Optional: fallback to HOSTNAME if it looks like a Docker ID (12–64 hex chars)
if [ -z "$CID" ] && printf '%s\n' "$HOSTNAME" | grep -Eq '^[0-9a-f]{12,64}$'; then
  CID="$HOSTNAME"
fi

if [ -z "$CID" ]; then
  echo "get-docker-config: WARNING: could not determine container ID; skipping" >&2
  exit 0
fi

if [ ! -S /var/run/docker.sock ]; then
  echo "get-docker-config: WARNING: /var/run/docker.sock not available; skipping" >&2
  exit 0
fi

# 2) Fetch full container JSON and write to /scripts/docker.config
if curl -s --unix-socket /var/run/docker.sock \
       "http://localhost/containers/${CID}/json" \
       -o "${CONFIG_PATH}"
then
  # 3) Adjust ownership/permissions for nsadmin:nsadmin
  chown nsadmin:nsadmin "${CONFIG_PATH}" 2>/dev/null || true
  chmod 640 "${CONFIG_PATH}" 2>/dev/null || true
  echo "get-docker-config: wrote ${CONFIG_PATH} for CID=${CID}" >&2
else
  echo "get-docker-config: WARNING: Docker API request failed for CID=${CID}" >&2
fi
