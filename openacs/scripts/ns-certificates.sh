# ns-certificates.sh -- TLS certificate setup helper for NaviServer containers (sourced)
#
# This file is a sourced helper (no side effects on its own). It provides
# ns_setup_certificates(), which resolves a certificate path following the
# convention:
#
#   certdir      = <serverroot>/certificates
#   default PEM  = <certdir>/<hostname>.pem   (combined key+cert)
#
# Function:
#   ns_setup_certificates <serverroot> <hostname> [<passed_cert>]
#
# Inputs:
#   serverroot   Required. Application/server root directory.
#   hostname     Required. Used for default PEM name and CN/SAN for self-signed.
#   passed_cert  Optional. Full path to an existing PEM (key+cert).
#
# Mode selection (optional, via environment):
#   certificatesdir
#     If set AND non-empty => "external management" mode:
#       - no copying into the default location
#       - missing/unreadable cert fails (unless ns_allow_self_signed=1)
#
# Behavior:
#   Internal mode (default): normalize to default PEM path; if passed_cert is
#   provided and readable, copy it into the default location; if the default
#   PEM is missing and allowed, generate a self-signed certificate.
#
# Output:
#   On success: prints the resolved certificate path to stdout.
#   On failure: prints diagnostics to stderr and returns non-zero.
#
# Variables:
#   Read (from environment):
#     certificatesdir               If set and non-empty => external cert management mode.
#     ns_certs_external             Optional override (1/0). If set, overrides certificatesdir detection.
#     ns_allow_self_signed          Optional (1/0). Default: 1 in internal mode, 0 in external mode.
#     ns_fail_hard_missing_explicit Optional (1/0). Default: 1.
#     ns_certdir                    Optional override of cert directory (default: <serverroot>/certificates).
#     ns_default_cert               Optional override of default cert path (default: <ns_certdir>/<hostname>.pem).
#
#   Set/used (global in caller shell; POSIX sh has no local vars):
#     ns_serverroot   (function arg) serverroot passed to ns_setup_certificates
#     ns_hostname     (function arg) hostname passed to ns_setup_certificates
#     passed_cert     (function arg) optional input cert path
#     ns_certdir      resolved/override cert directory
#     ns_default_cert resolved/override default cert path
#     external_certs  computed mode flag (0/1)
#     cert_source     computed mode label (internal-default / external-certificatesdir)
#     cert            resolved certificate path used internally (printed on stdout)
#     tmpcert         temporary file path used during atomic copy (internal mode)
#     tmpkey/tmpcrt   temporary files used for self-signed generation


ns_log() { printf '%s\n' "$*" >&2; }

ns_setup_certificates() {
  ns_serverroot=$1
  ns_hostname=$2
  passed_cert=${3-}

  : "${ns_serverroot:?}"
  : "${ns_hostname:?}"

  ns_certdir=${ns_certdir:-"$ns_serverroot/certificates"}
  ns_default_cert=${ns_default_cert:-"$ns_certdir/$ns_hostname.pem"}

  if [ -n "${ns_certs_external+x}" ]; then
    external_certs=$ns_certs_external
  else
    external_certs=0
    if [ -n "${certificatesdir+x}" ] && [ -n "${certificatesdir}" ]; then
      external_certs=1
    fi
  fi

  if [ -z "${ns_allow_self_signed+x}" ]; then
    if [ "$external_certs" -eq 1 ]; then
      ns_allow_self_signed=0
    else
      ns_allow_self_signed=1
    fi
  fi

  ns_fail_hard_missing_explicit=${ns_fail_hard_missing_explicit:-1}

  mkdir -p "$ns_certdir" || return 1

  if [ "$external_certs" -eq 1 ]; then
    cert_source="external-certificatesdir"

    if [ -n "$passed_cert" ]; then
      cert=$passed_cert
      case $cert in
        "$ns_certdir"/*) : ;;
        *)
          ns_log "WARNING: external cert mode, passed cert '$cert' is outside '$ns_certdir'."
          ns_log "WARNING: No copying will be performed; automated renewal is not supported out-of-the-box."
          ;;
      esac
    else
      cert=$ns_default_cert
    fi

    if [ ! -r "$cert" ] || [ ! -s "$cert" ]; then
      if [ "$ns_allow_self_signed" -ne 1 ]; then
        ns_log "ERROR: TLS certificate '$cert' is missing or unreadable (external certificatesdir mode)."
        return 1
      fi
      ns_log "WARNING: external cert mode but ns_allow_self_signed=1; generating self-signed at '$cert'."
    fi

  else
    cert_source="internal-default"
    cert=$ns_default_cert

    if [ -n "$passed_cert" ]; then
      if [ ! -r "$passed_cert" ] || [ ! -s "$passed_cert" ]; then
        if [ "$ns_fail_hard_missing_explicit" -eq 1 ]; then
          ns_log "ERROR: passed cert '$passed_cert' is missing/unreadable."
          return 1
        else
          ns_log "WARNING: passed cert '$passed_cert' missing/unreadable; continuing with internal default/generation."
          passed_cert=
        fi
      fi

      if [ -n "$passed_cert" ] && [ "$passed_cert" != "$ns_default_cert" ]; then
        ns_log "Certificate provided ('$passed_cert'), copying to standard location '$ns_default_cert'"

        tmpcert=$(mktemp "${ns_certdir}/.${ns_hostname}.pem.XXXXXX") || return 1
        cp -f "$passed_cert" "$tmpcert" || { rm -f "$tmpcert"; return 1; }
        chown nsadmin:nsadmin "$tmpcert" 2>/dev/null || true
        chmod 600 "$tmpcert" || { rm -f "$tmpcert"; return 1; }
        mv -f "$tmpcert" "$ns_default_cert" || { rm -f "$tmpcert"; return 1; }
      fi
    fi
  fi

  # Self-signed generation if needed/allowed
  if [ ! -s "$cert" ]; then
    if [ "$ns_allow_self_signed" -ne 1 ]; then
      ns_log "ERROR: TLS certificate missing at '$cert' and ns_allow_self_signed=0."
      return 1
    fi

    ns_log "No TLS certificate found at '$cert' (source=$cert_source). Generating self-signed certificate..."

    tmpkey=$(mktemp) || return 1
    tmpcrt=$(mktemp) || { rm -f "$tmpkey"; return 1; }

    openssl req -x509 -nodes -newkey rsa:4096 \
      -keyout "$tmpkey" \
      -out "$tmpcrt" \
      -days 365 \
      -subj "/CN=${ns_hostname}" \
      -addext "subjectAltName=DNS:${ns_hostname}" || {
        rm -f "$tmpkey" "$tmpcrt"
        return 1
      }

    cat "$tmpkey" "$tmpcrt" >"$cert" || { rm -f "$tmpkey" "$tmpcrt"; return 1; }
    chown nsadmin:nsadmin "$cert" 2>/dev/null || true
    chmod 600 "$cert" || return 1
    rm -f "$tmpkey" "$tmpcrt"

    ns_log "Self-signed certificate created at $cert"
  fi

  ns_log "Certificate source '$cert_source'"
  ns_log "Certificate '$cert' certdir '$ns_certdir'"

  # Return the resolved certificate path on stdout
  printf '%s\n' "$cert"
  return 0
}
