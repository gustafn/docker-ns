#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
set -e

# Defaults for global munin paths and our single-node setup.
# These defaults will be used by envsubst in munin.conf.template.

: "${MUNIN_DB_DIR:=/var/lib/munin}"
: "${MUNIN_HTML_DIR:=/var/www/munin}"
: "${MUNIN_LOG_DIR:=/var/log/munin}"
: "${MUNIN_RUN_DIR:=/var/run/munin}"
: "${MUNIN_TPL_DIR:=/etc/munin/templates}"

# Logical "site name" / host entry
: "${MUNIN_HOSTNAME:=openacs.org}"
# Address of the node to poll (your munin-node container or host)
: "${MUNIN_NODE_ADDRESS:=munin-node}"

export MUNIN_DB_DIR MUNIN_HTML_DIR MUNIN_LOG_DIR MUNIN_RUN_DIR MUNIN_TPL_DIR
export MUNIN_HOSTNAME MUNIN_NODE_ADDRESS


# Generate /etc/munin/munin.conf from template unless user bind-mounts their own
if [ ! -f /etc/munin/munin.conf ]; then
    echo "munin-master: generating /etc/munin/munin.conf from template"
    envsubst < /etc/munin/munin.conf.template > /etc/munin/munin.conf
    echo "Generated /etc/munin/munin.conf"
    echo "---"
    sed 's/^/    /' /etc/munin/munin.conf
    echo "---"    
fi

# --- Map munin UID/GID to host user specified by MUNIN_HOST_USER (e.g. nsadmin) ---

if [ -n "$MUNIN_HOST_USER" ] && [ -f /host-etc/passwd ]; then
    host_entry="$(grep "^${MUNIN_HOST_USER}:" /host-etc/passwd || true)"
    if [ -n "$host_entry" ]; then
        host_uid="$(echo "$host_entry" | cut -d: -f3)"
        host_gid="$(echo "$host_entry" | cut -d: -f4)"

        echo "munin-master: mapping user 'munin' to host user '$MUNIN_HOST_USER' (uid=$host_uid gid=$host_gid)"

        # Ensure group exists with that GID
        if ! grep -q ":${host_gid}:" /etc/group; then
            echo "munin:x:${host_gid}:munin" >> /etc/group
        fi

        # Adjust or create munin user with host uid/gid
        if grep -q '^munin:' /etc/passwd; then
            # Rewrite existing munin entry
            sed -i -E "s/^(munin:[^:]*:)[0-9]+:[0-9]+:/\1${host_uid}:${host_gid}:/" /etc/passwd
        else
            echo "munin:x:${host_uid}:${host_gid}:Munin user:/var/lib/munin:/bin/sh" >> /etc/passwd
        fi

        # Fix ownership of bind-mounted dirs to match the host UID/GID
        chown -R "${host_uid}:${host_gid}" /var/lib/munin /var/log/munin /var/www/munin 2>/dev/null || true
    else
        echo "munin-master: MUNIN_HOST_USER '$MUNIN_HOST_USER' not found in /host-etc/passwd" >&2
    fi
fi

# Ensure directories exist and are owned by 'munin'
mkdir -p "$MUNIN_DB_DIR" "$MUNIN_HTML_DIR" "$MUNIN_LOG_DIR" "$MUNIN_RUN_DIR"

echo "munin-master: pre-map chown test: $(id)"
echo "munin-master: fstype html: $(stat -f -c %T "$MUNIN_HTML_DIR" 2>/dev/null || echo unknown)"

chown -R munin:munin "$MUNIN_DB_DIR" "$MUNIN_LOG_DIR" "$MUNIN_RUN_DIR" || true

fstype="$(stat -f -c %T "$MUNIN_HTML_DIR" 2>/dev/null || true)"
if [ "$fstype" != "nfs" ] && [ "$fstype" != "nfs4" ]; then
  chown -R munin:munin "$MUNIN_HTML_DIR" 2>/dev/null || true
else
  echo "munin-master: $MUNIN_HTML_DIR is $fstype; skipping chown"
fi

MUNIN_NODE_ADDRESS="${MUNIN_NODE_ADDRESS:-munin-node}"
echo "munin-master: connectivity check to munin-node..."
if nc -z -w 3 "$MUNIN_NODE_ADDRESS" 4949 >/dev/null 2>&1; then
    echo "  [OK]  TCP $MUNIN_NODE_ADDRESS:4949"
else
    echo "  [WARN] Cannot reach $MUNIN_NODE_ADDRESS:4949 (will retry via cron)"
fi

mkdir -p /var/cache/fontconfig
chown munin:munin /var/cache/fontconfig 2>/dev/null || true

if ! grep -q 'munin-cron' /etc/crontabs/root 2>/dev/null; then
    cat >> /etc/crontabs/root <<'EOF'
# Run Munin every 5 minutes
*/1 * * * * su -s /bin/sh munin -c /usr/bin/munin-cron
EOF
fi
chmod 600 /etc/crontabs/root

# Run one initial munin-cron so you don't have to wait for the first 5-minute tick
echo "munin-master: running initial munin-cron..."
#su -s /bin/sh munin -c /usr/bin/munin-cron || true

echo "munin-master: starting crond..."
exec crond -f -l 8 -L /var/log/cron.log -c /etc/crontabs
