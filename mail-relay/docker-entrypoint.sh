#!/bin/sh
# SPDX-License-Identifier: MPL-2.0

set -e

# Set defaults if not provided via environment
: "${POSTFIX_MYORIGIN:=openacs.org}"
: "${POSTFIX_TLS_CERT_FILE:=/var/www/openacs.org/etc/openacs.org.pem}"
: "${POSTFIX_TLS_KEY_FILE:=${POSTFIX_TLS_CERT_FILE}}"
: "${POSTFIX_MYNETWORKS:=127.0.0.0/8 [::1]/128 172.16.0.0/12 172.27.0.0/16}"
#: "${POSTFIX_RELAYPORT:=25}"


export POSTFIX_MYORIGIN POSTFIX_TLS_CERT_FILE POSTFIX_TLS_KEY_FILE POSTFIX_MYNETWORKS

# Only (re)generate if not present, or always if you prefer
if [ ! -f /etc/postfix/main.cf ]; then
    echo "Generating /etc/postfix/main.cf from template"
    envsubst < /etc/postfix/main.cf.template > /etc/postfix/main.cf
    echo "Generated /etc/postfix/main.cf"
    echo "---"
    sed 's/^/    /' /etc/postfix/main.cf
    echo "---"
fi

# quick sanity check on config.
postfix check || true

# Start rsyslog if available so that mail.* -> /var/log/mail.log works
if command -v rsyslogd >/dev/null 2>&1; then
    rsyslogd
fi

echo "$(date '+%Y-%m-%d %H:%M:%S%z') mail-reley: starting postfix ..."
# Run Postfix in the foreground so Docker/Portainer can track health
exec postfix start-fg

