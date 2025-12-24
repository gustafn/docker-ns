#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# ensure-secrets.sh
#
# This script guarantees that all required OpenACS and PostgreSQL secrets
# exist and are available under the unified path:
#
#       /run/oacs-secrets
#
# The location is provided by a Docker volume which may be EITHER:
#
#   1. An internal named volume (default)
#        - Nothing is required on the host
#        - Missing secrets are generated on first container startup
#
#   2. A host bind-mounted directory (external mode)
#        - Files such as ${config_dir}/secrets/*.txt exist on the host
#        - No secrets are generated; the script simply reads the files
#
# Secrets handled:
#       - psql_password.txt      (database password for PostgreSQL and OpenACS)
#       - cluster_secret.txt     (OpenACS cluster secret)
#       - parameter_secret.txt   (OpenACS parameter encryption key)
#
# Behavior:
#   * If a secret file does not exist (internal mode), a default or random value
#     is generated and stored with permissions 600.
#   * If a secret file exists (external mode), its value is read without changes.
#   * Environment variables oacs_db_passwordfile, oacs_clusterSecret,
#     and oacs_parameterSecret are exported for use by the main OpenACS
#     configuration generator.
#
# This script is safe to run multiple times and is normally invoked on every
# container startup via container-setup-openacs.sh. Only the first run on an
# empty internal volume actually creates files.
#
# The goal is to provide a unified mechanism that supports:
#     - "all-included" demo deployments (no host preparation needed)
#     - production deployments with externally managed secret files
#
# ----------------------------------------------------------------------

set -e

dir="/run/secrets"
mkdir -p "$dir"
chgrp nsadmin "$dir" 2>/dev/null || true
chmod 750 "$dir"

new_secret() {
  local name="$1"
  local desc="$2"
  local default="$3"

  local path="${dir}/${name}"

  if [ -f "$path" ]; then
    echo "ensure-secrets: keeping existing ${name}"
    return
  fi

  if [ -z "$default" ]; then
      echo "ensure-secrets: generating ${name} (${desc})"
      openssl rand -base64 32 > "$path"
  else
    echo "ensure-secrets: using default for ${name} (${desc})"
    printf '%s\n' "$default" > "$path"
    if [ "$name" = "psql_password" ] && [ "$default" = "openacs" ]; then
        echo "ensure-secrets: psql_password default is: $default"
    fi
  fi
  chgrp nsadmin "$path" 2>/dev/null || true
  chmod 640 "$path"
}

new_secret "psql_password"    "PostgreSQL / OpenACS DB password" "${oacs_db_password:-openacs}"
new_secret "cluster_secret"   "OpenACS cluster secret"           "${oacs_clusterSecret:-}"
new_secret "parameter_secret" "OpenACS parameter secret"         "${oacs_parameterSecret:-}"

export oacs_parameterSecret="$(cat "${dir}/parameter_secret")"
export oacs_clusterSecret="$(cat "${dir}/cluster_secret")"
