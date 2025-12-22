#!/bin/sh
# SPDX-License-Identifier: MPL-2.0

set -eu

MUNIN_CONF=/etc/munin/munin-node.conf
MUNIN_CONF_TEMPLATE=/etc/munin/munin-node.conf.template

# Munin node name (as seen by master)
MUNIN_HOSTNAME="${MUNIN_HOSTNAME:-$(hostname)}"

# Which master(s) may connect (CIDR notation)
MUNIN_ALLOW_CIDR="${MUNIN_ALLOW_CIDR:-127.0.0.1/32}"

# NaviServer/OpenACS instance details (for NaviServer plugins)
NS_SERVER_NAME="${NS_SERVER_NAME:-openacs.org}"      # used in plugin names
NS_ADDRESS="${NS_ADDRESS:-openacs-org}"              # Docker service name of OpenACS container
NS_PORT="${NS_PORT:-8080}"                           # HTTP port inside OpenACS container
NS_URL_PATH="${NS_URL_PATH:-/SYSTEM/munin.tcl?t=}"   # path to interface script
NS_PLUGIN_CONF_TEMPLATE="${NS_PLUGIN_CONF_TEMPLATE:-/etc/munin/naviserver-plugin.conf.template}"

export MUNIN_HOSTNAME MUNIN_ALLOW_CIDR NS_SERVER_NAME NS_ADDRESS NS_PORT NS_URL_PATH

# ----------------------------------------------------------------------
# Generate munin-node.conf from template if none is provided by bind-mount
# ----------------------------------------------------------------------
if [ ! -f "$MUNIN_CONF" ]; then
    if [ -f "$MUNIN_CONF_TEMPLATE" ]; then
        echo "munin-node: generating $MUNIN_CONF from $MUNIN_CONF_TEMPLATE"
        envsubst < "$MUNIN_CONF_TEMPLATE" > "$MUNIN_CONF"
        echo "Generated $MUNIN_CONF"
        echo "---"
        sed 's/^/    /' "$MUNIN_CONF"
        echo "---"
    else
        echo "munin-node: $MUNIN_CONF not found and no template $MUNIN_CONF_TEMPLATE available, aborting"
        exit 1
    fi
else
    echo "munin-node: using existing $MUNIN_CONF (bind-mounted or image-provided)"
fi

echo "You might check the used munin-node.conf via:"
echo "    docker exec -it munin-node sed 's/^/   /'   /etc/munin/munin-node.conf"
echo " "
echo "To try the interaction of the plugin with the server:"
echo "    munin-run naviserver_openacs.org_views config"
echo "    munin-run naviserver_openacs.org_views"
echo " "

# ----------------------------------------------------------------------
# Plugin configuration for NaviServer/OpenACS
# ----------------------------------------------------------------------
install_munin_tcl() {
  # Where the Dockerfile put it:
  local src="/usr/local/share/munin-plugins-ns/munin.tcl"

  # Where OpenACS expects it (adjust if your mount uses a different base):
  # Example: /oacs-system is a bind mount of ${oacs_root}
  local dst_dir="${OACS_SYSTEM_DIR:-/oacs-system}"
  local dst="${dst_dir}/munin.tcl"

  # Sanity checks
  if [ ! -r "$src" ]; then
    echo "munin-node: install_munin_tcl: source missing: $src (skipping)"
    return 0
  fi
  if [ ! -d "$dst_dir" ]; then
    echo "munin-node: install_munin_tcl: target dir missing: $dst_dir (skipping)"
    return 0
  fi

  # Determine ownership of the target directory (numeric uid/gid)
  # stat -c works on busybox and GNU; if yours is different, tell me.
  local uid gid
  uid="$(stat -c '%u' "$dst_dir")" || return 0
  gid="$(stat -c '%g' "$dst_dir")" || return 0

  # If already installed and identical, do nothing
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    echo "munin-node: munin.tcl already up-to-date at $dst"
    return 0
  fi

  echo "munin-node: installing munin.tcl to $dst_dir as uid=${uid} gid=${gid}"

  # Do the copy+chmod as the directory owner (important for NFS root-squash)
  su-exec "${uid}:${gid}" sh -c "
    umask 022
    cp -f '$src' '$dst'
    chmod 0644 '$dst'
  " || {
  echo "munin-node: WARN: install failed (uid=${uid} gid=${gid})"
  return 0
}
  # Optional: try to set group too (may fail on NFS, ignore)
  chgrp "$gid" "$dst" 2>/dev/null || true
}

echo "munin-node: pre install munin.tcl: $(id)"

install_munin_tcl

mkdir -p /etc/munin/plugin-conf.d /etc/munin/plugins /usr/local/munin/lib/plugins

echo "Generating /etc/munin/plugin-conf.d/naviserver from template"
envsubst < "${NS_PLUGIN_CONF_TEMPLATE}" > /etc/munin/plugin-conf.d/naviserver

# Symlink the naviserver_* plugins for this server instance
plugins="locks.busy locks.nr locks.wait logstats lsof memsize \
         responsetime serverstats threadcpu threads users users24 views"

for p in $plugins; do
  src="/usr/local/munin/lib/plugins/naviserver_${p}"
  dst="/etc/munin/plugins/naviserver_${NS_SERVER_NAME}_${p}"
  if [ -x "$src" ]; then
      ln -sf "$src" "$dst"
      echo "... creating link: ln -sf ${src} ${dst}"
  else
    echo "Warning: plugin $src not found or not executable"
  fi
done


# ----------------------------------------------------------------------
# Plugin configuration for PostgreSQL
# ----------------------------------------------------------------------
# Normalize DB_* and resolve DB_EFFECTIVE_HOST/DB_EFFECTIVE_DESC
. /scripts/oacs-db-env.sh

# Only configure postgres plugins if we have DB_NAME and DB_USER
if [ -n "$DB_NAME" ] && [ -n "$DB_USER" ]; then
  echo "munin-node: configuring postgres_* plugins for ${DB_USER}@${DB_EFFECTIVE_DESC}"

  mkdir -p /etc/munin/plugins /etc/munin/plugin-conf.d

  cat >/etc/munin/plugin-conf.d/postgres <<EOF
[postgres_*]
  env.PGHOST     ${DB_EFFECTIVE_HOST}
  env.PGPORT     ${DB_PORT}
  env.PGUSER     ${DB_USER}
  env.PGDATABASE ${DB_NAME}
EOF

  DB_SAFE="$(printf '%s' "$DB_NAME" | tr '. -' '___')"

  # Enable wildcard plugins with a suffix
  ln -sf /usr/share/munin/plugins/postgres_tuples_      "/etc/munin/plugins/postgres_tuples_${DB_SAFE}"
  ln -sf /usr/share/munin/plugins/postgres_scans_       "/etc/munin/plugins/postgres_scans_${DB_SAFE}"
  # There is a bug, when using the "connections" plugin due to incompatible versions of the perl plugin
  #ln -sf /usr/share/munin/plugins/postgres_connections_ "/etc/munin/plugins/postgres_connections_${DB_SAFE}"

  # Non-wildcard plugin (no suffix needed)
  ln -sf /usr/share/munin/plugins/postgres_bgwriter     /etc/munin/plugins/postgres_bgwriter

  if [ -f /run/secrets/psql_password ]; then
      PW="$(cat /run/secrets/psql_password)"
    printf '  env.PGPASSWORD %s\n' "$PW" >> /etc/munin/plugin-conf.d/postgres
  fi
fi

# ----------------------------------------------------------------------
# General startup code
# ----------------------------------------------------------------------
echo "Starting munin-node for ${MUNIN_HOSTNAME}, allowing ${MUNIN_ALLOW_CIDR}"
echo "Naviserver plugins targeting http://${NS_ADDRESS}:${NS_PORT}${NS_URL_PATH}"

# Optional: Munin master host/port (for info only; master actually connects to us)
MUNIN_MASTER_HOST="${MUNIN_MASTER_HOST:-munin-master}"
MUNIN_MASTER_PORT="${MUNIN_MASTER_PORT:-80}"

echo "munin-node: connectivity checks..."

# Helper: test host:port with nc
check_tcp() {
  host="$1"; port="$2"; label="$3"
  for i in 1 2 3 4 5; do
    if nc -z -w 2 "$host" "$port" >/dev/null 2>&1; then
      echo "  [OK]  $label $host:$port"
      return 0
    fi
    sleep 2
  done
  echo "  [WARN] Cannot reach $host:$port (after retries)"
  return 1
}

# Helper: simple DNS/ICMP check
check_host() {
    host="$1"
    if ping -c1 -W1 "$host" >/dev/null 2>&1; then
        echo "  [OK]  host $host reachable (ping)"
    else
        echo "  [WARN] host $host not reachable (ping failed)"
    fi
}

# Check OpenACS (for naviserver_* plugins)
check_host "$NS_ADDRESS"
check_tcp  "$NS_ADDRESS" "$NS_PORT" "NaviServer"

# Optionally: check that the munin-master name resolves/answers (for human info)
check_host "$MUNIN_MASTER_HOST"
# We are not connecting to the node via port 80, but use just the generated files.
#check_tcp  "$MUNIN_MASTER_HOST" "$MUNIN_MASTER_PORT" "munin master"

echo "munin-node: connectivity checks done."

exec "$@"
