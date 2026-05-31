#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0


#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# ensure-secrets.sh
#
# Ensure that the required OpenACS and PostgreSQL secret files exist under:
#
#       /run/secrets
#
# This directory is normally provided by the container setup as either:
#
#   1. A Docker named volume
#        - Used for self-contained/demo deployments.
#        - Missing secrets are generated on first startup.
#
#   2. A host bind mount
#        - Used for production deployments with externally managed files.
#        - The directory may live on NFS and may use root-squash.
#        - In this case, root inside the container might not be able to
#          create or chmod files, while HOST_USER/nsadmin can.
#
# Secrets handled:
#
#       psql_password
#           PostgreSQL/OpenACS database password.
#
#       cluster_secret
#           OpenACS cluster secret.
#
#       parameter_secret
#           OpenACS parameter encryption secret.
#
# Behavior:
#
#   * Existing secret files are kept unchanged.
#
#   * Missing secrets are generated only when /run/secrets is writable by
#     either the current user or HOST_USER.
#
#   * HOST_USER and HOST_GROUP default to nsadmin, matching the main
#     container setup script:
#
#         HOST_USER="${HOST_USER:-nsadmin}"
#         HOST_GROUP="${HOST_GROUP:-$HOST_USER}"
#
#   * Directory ownership and permission changes are best-effort only.
#     This is intentional, since externally mounted directories, especially
#     NFS mounts with root-squash, may reject chmod/chgrp from container root.
#
#   * When root cannot write to /run/secrets but HOST_USER can, secret files
#     are created via "su" as HOST_USER.
#
#   * The script exports:
#
#         oacs_db_passwordfile=/run/secrets/psql_password
#         oacs_clusterSecret
#         oacs_parameterSecret
#
#     for callers that source or otherwise consume the generated environment.
#
# Notes:
#
#   This script is safe to run multiple times. Only missing files are created.
#   It is normally invoked early by container-setup-openacs.sh, before
#   wait-for-postgres.sh, so that the PostgreSQL password file is available
#   before the database readiness check.
#
# ----------------------------------------------------------------------
#

set -euo pipefail

: "${HOSTNAME:?}"

HOST_USER="${HOST_USER:-nsadmin}"
HOST_GROUP="${HOST_GROUP:-$HOST_USER}"

dir="/run/secrets"

have_host_user=0
if id "$HOST_USER" >/dev/null 2>&1; then
  have_host_user=1
else
  echo "ensure-secrets: warning: HOST_USER '$HOST_USER' does not exist; root-only mode" >&2
fi

can_write_dir_as_current_user() {
  local d=$1
  local tmp

  tmp="${d}/.ensure-secrets-write-test.$$"
  { : >"$tmp"; } 2>/dev/null && rm -f "$tmp"
}

can_write_dir_as_host_user() {
  local d=$1

  if [ "$have_host_user" != 1 ]; then
    return 1
  fi

  su -s /bin/sh "$HOST_USER" -c '
    d=$1
    tmp="${d}/.ensure-secrets-write-test.$$"
    : > "$tmp" && rm -f "$tmp"
  ' sh "$d"
}

read_secret() {
  local path=$1

  if [ -r "$path" ]; then
    cat "$path"
  elif [ "$have_host_user" = 1 ]; then
    su -s /bin/sh "$HOST_USER" -c '
      cat "$1"
    ' sh "$path"
  else
    return 1
  fi
}

mkdir -p "$dir" 2>/dev/null || {
  echo "ensure-secrets: warning: could not mkdir $dir; assuming it is externally managed" >&2
}

chgrp "$HOST_GROUP" "$dir" 2>/dev/null || true
chmod 750 "$dir" 2>/dev/null || {
  echo "ensure-secrets: warning: could not chmod $dir; continuing" >&2
}

write_mode="none"

if can_write_dir_as_current_user "$dir"; then
  write_mode="current"
  echo "ensure-secrets: $dir is writable by current user"
elif can_write_dir_as_host_user "$dir"; then
  write_mode="host"
  echo "ensure-secrets: $dir is writable by $HOST_USER"
else
  echo "ensure-secrets: warning: $dir is not writable by current user or $HOST_USER" >&2
fi

create_secret_as_current_user() {
  local path=$1
  local default=$2
  local old_umask

  old_umask=$(umask)
  umask 027

  if [ -z "$default" ]; then
    openssl rand -base64 32 >"$path"
  else
    printf '%s\n' "$default" >"$path"
  fi

  umask "$old_umask"
}

create_secret_as_host_user() {
  local path=$1
  local default=$2

  if [ "$have_host_user" != 1 ]; then
    return 1
  fi

  if [ -z "$default" ]; then
    su -s /bin/sh "$HOST_USER" -c '
      path=$1
      umask 027
      openssl rand -base64 32 > "$path"
    ' sh "$path"
  else
    su -s /bin/sh "$HOST_USER" -c '
      path=$1
      value=$2
      umask 027
      printf "%s\n" "$value" > "$path"
    ' sh "$path" "$default"
  fi
}

new_secret() {
  local name=$1
  local desc=$2
  local default=$3
  local path

  path="${dir}/${name}"

  if [ -f "$path" ]; then
    echo "ensure-secrets: keeping existing ${name}"
    return 0
  fi

  if [ "$write_mode" = "none" ]; then
    echo "ensure-secrets: ERROR: missing ${path}" >&2
    echo "ensure-secrets: ERROR: ${dir} is not writable by current user or ${HOST_USER}" >&2
    echo "ensure-secrets: Either pre-create ${name}, or mount a writable secrets directory." >&2
    return 1
  fi

  if [ -z "$default" ]; then
    echo "ensure-secrets: generating ${name} (${desc})"
  else
    echo "ensure-secrets: using default for ${name} (${desc})"
  fi

  case "$write_mode" in
    current)
      create_secret_as_current_user "$path" "$default"
      ;;
    host)
      create_secret_as_host_user "$path" "$default"
      ;;
    *)
      return 1
      ;;
  esac

  chgrp "$HOST_GROUP" "$path" 2>/dev/null || true
  chmod 640 "$path" 2>/dev/null || {
    if [ "$have_host_user" = 1 ]; then
      su -s /bin/sh "$HOST_USER" -c '
        chmod 640 "$1"
      ' sh "$path" 2>/dev/null || true
    fi
  }

  if [ "$name" = "psql_password" ] && [ "$default" = "openacs" ]; then
    echo "ensure-secrets: psql_password default is: $default"
  fi
}

new_secret "psql_password"    "PostgreSQL / OpenACS DB password" "${oacs_db_password:-openacs}"
new_secret "cluster_secret"   "OpenACS cluster secret"           "${oacs_clusterSecret:-}"
new_secret "parameter_secret" "OpenACS parameter secret"         "${oacs_parameterSecret:-}"

oacs_db_passwordfile="${dir}/psql_password"
export oacs_db_passwordfile

oacs_parameterSecret=$(read_secret "${dir}/parameter_secret") || exit 1
export oacs_parameterSecret

oacs_clusterSecret=$(read_secret "${dir}/cluster_secret") || exit 1
export oacs_clusterSecret
