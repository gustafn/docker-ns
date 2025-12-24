#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
set -e

# Normalize and resolve effective host
. /scripts/oacs-db-env.sh

echo "Waiting for Postgres at ${DB_EFFECTIVE_DESC} (db=${DB_NAME}, user=${DB_USER})..."

i=0
max_tries=60

while [ $i -lt $max_tries ]; do
  if pg_isready -h "$DB_EFFECTIVE_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
    echo "Postgres is ready."
    exit 0
  fi
  i=$((i+1))
  echo "Postgres not ready yet (try ${i}/${max_tries})..."
  sleep 2
done

echo "ERROR: Postgres did not become ready in time." >&2
exit 1
