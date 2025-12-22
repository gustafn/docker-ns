#!/bin/sh
#
# oacs-db-env.sh
#
# Normalize DB_* environment variables from the various
# oacs_* / db_* / service env vars used in:
#   - all-inclusive setup (internal postgres)
#   - external-DB setup (host postgres)
#
# And compute an "effective" host to use for libpq / pg_isready:
#   - if DB_HOST starts with '/', treat as socket directory
#   - if DB_HOST is empty/localhost/127.0.0.1 and socket dir looks usable,
#     prefer UNIX socket
#   - otherwise, use DB_HOST as a normal TCP host.
#
# This file MUST NOT exit the shell; it is meant to be sourced:
#   . /scripts/oacs-db-env.sh
#
# The computed final variables are
#    DB_NAME DB_HOST DB_PORT DB_USER DB_SOCKET_DIR
#    DB_EFFECTIVE_HOST DB_EFFECTIVE_DESC
#
# * For TCP: DB_EFFECTIVE_HOST = DB_HOST → pg_isready -h postgres -p 5432 ...
# * For UNIX sockets: DB_EFFECTIVE_HOST = /var/run/postgresql
#     libpq interprets that as “socket dir”
#     -> pg_*  -h /var/run/postgresql -p 5432 ...


# 1) Basic normalization

DB_NAME="${DB_NAME:-${oacs_db_name:-${service:-oacs-5-10}}}"
DB_HOST="${DB_HOST:-${oacs_db_host:-${db_host:-postgres}}}"
DB_PORT="${DB_PORT:-${oacs_db_port:-${db_port:-5432}}}"
DB_USER="${DB_USER:-${oacs_db_user:-${db_user:-openacs}}}"

DB_SOCKET_DIR="${DB_SOCKET_DIR:-${PGSOCKETDIR:-/var/run/postgresql}}"

# 2) Effective host / DSN resolution

# Defaults: assume plain TCP to DB_HOST:DB_PORT
DB_EFFECTIVE_HOST="$DB_HOST"
DB_EFFECTIVE_DESC="${DB_HOST}:${DB_PORT}"

case "$DB_HOST" in
  /*)
    # Explicit socket directory
    DB_EFFECTIVE_HOST="$DB_HOST"
    DB_EFFECTIVE_DESC="unix:${DB_HOST}/.s.PGSQL.${DB_PORT}"
    ;;
  ""|"localhost"|"127.0.0.1")
    # Local DB: prefer socket if it looks available
    if [ -S "${DB_SOCKET_DIR}/.s.PGSQL.${DB_PORT}" ] || [ -d "$DB_SOCKET_DIR" ]; then
      DB_EFFECTIVE_HOST="$DB_SOCKET_DIR"
      DB_EFFECTIVE_DESC="unix:${DB_SOCKET_DIR}/.s.PGSQL.${DB_PORT}"
    fi
    ;;
esac
