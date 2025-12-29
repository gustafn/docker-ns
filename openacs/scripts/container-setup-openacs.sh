#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0

echo "-- container-setup-openacs.sh called --"

: "${base_image:?}"

: "${oacs_serverroot:?}"
: "${oacs_hostname:?}"
: "${oacs_db_host:?}"
: "${oacs_db_name:?}"
: "${oacs_db_user:?}"
: "${oacs_tag:-oacs-5-10}"

: "${install_dotlrn:-0}"

#
# Get setup info from compilation steps:
. /usr/local/ns/lib/nsConfig.sh

# Obtain Docker info (if possible) and write it to /scripts/docker.config
if [ -x /scripts/get-docker-config.sh ]; then
  /scripts/get-docker-config.sh
fi

#
# Ensure secrets exist (psql_password, cluster_secret, parameter_secret).
# This does not depend on the final UID/GID mapping; files will track
# group 'nsadmin' even after groupmod/usermod run.
#
if [ -x /scripts/ensure-secrets.sh ]; then
    /scripts/ensure-secrets.sh
fi

#
# Wait for PostgreSQL, now that /run/secrets/psql_password exists.
# You can add guards here if you want to skip this for non-PG setups.
#
if [ -x /scripts/wait-for-postgres.sh ]; then
    /scripts/wait-for-postgres.sh
fi


# Handling configuration files (opt-in to use alternate name)
#   If 'nsdconfig' is set, treat it as a relative path under
#     <oacs_serverroot>/etc/<nsdconfig>
#   If empty => default <hostname>-config.tcl
#
# If 'nsdconfig' is UNSET use
#   /usr/local/ns/conf/openacs-config.tcl)

if [ "${nsdconfig+x}" = x ]; then
  cfg_name=$nsdconfig
  if [ -z "$cfg_name" ]; then
    cfg_name="${oacs_hostname}-config.tcl"
  fi
  nsdconfig="${oacs_serverroot}/etc/${cfg_name}"
fi
echo "NaviServer configuration file ${nsdconfig}"
export nsdconfig

# shellcheck disable=SC1091
. /scripts/ns-certificates.sh

# If 'certificate' is UNSET, keep legacy behavior:
#   use ${oacs_certificate-} as passed cert path (if any), otherwise default/generate.

passed_cert=${oacs_certificate-}

if [ "${certificate+x}" = x ]; then
  # certificate variable is present => enable new/relative mode
  cert_name=$certificate
  if [ -z "$cert_name" ]; then
    cert_name=${oacs_hostname}.pem
  fi

  new_path="${oacs_serverroot}/certificates/${cert_name}"
  legacy_path="${oacs_serverroot}/etc/${cert_name}"

  if [ -r "$new_path" ] && [ -s "$new_path" ]; then
    passed_cert=$new_path
  elif [ -r "$legacy_path" ] && [ -s "$legacy_path" ]; then
    echo "WARNING: using legacy certificate path '$legacy_path'; prefer '$new_path'." >&2
    passed_cert=$legacy_path
  else
    # Nothing readable found; pass the new path so internal mode can generate
    # or external mode can fail hard (as configured).
    passed_cert=$new_path
  fi
fi

default_ns_certdir=${default_ns_certdir:-/var/lib/naviserver/certificates}

# Call the shared helper, which return resolved cert path on stdout
resolved_cert=$(
  ns_setup_certificates "$default_ns_certdir" "$oacs_hostname" "${passed_cert-}"
) || return 1

oacs_certificate=$resolved_cert
export oacs_certificate

CONTAINER_ALREADY_STARTED="/CONTAINER_ALREADY_STARTED_PLACEHOLDER"
if [ ! -e $CONTAINER_ALREADY_STARTED ] ; then
    touch $CONTAINER_ALREADY_STARTED
    echo "-- First container startup --"

    # shellcheck disable=SC2086
    if [ $alpine = "1" ] ; then
        apk add --no-cache shadow shadow-uidmap ${system_pkgs:-}
        # apk add lldb
    elif [ $debian = "1" ] ; then
        echo "... installing system_pkgs ' $system_pkgs' ..."
        if DEBIAN_FRONTEND=noninteractive DEBCONF_TERSE=true \
                          apt-get -y -qq install $system_pkgs \
                          -o Dpkg::Use-Pty=0 \
                          -o DPkg::Progress-Fancy=0 \
                          > /dev/null
        then
            echo "... installed system_pkgs ' $system_pkgs' DONE"
        else
            echo "ERROR: installing system_pkgs failed" >&2
            exit 1
        fi
    fi

    #
    # Map UID/GID of HOST_USER and HOST_GROUP to the container nsadmin user/group.
    # Always requires a bind-mount of /host-etc/passwd, and a bind-mount of
    # /host-etc/group as well when HOST_GROUP is used (or differs from HOST_USER).
    #
    if [ -f /host-etc/passwd ]; then
        #
        # Host user/group names to map to container nsadmin.
        # Defaults: nsadmin:nsadmin
        #
        HOST_USER="${HOST_USER:-nsadmin}"
        HOST_GROUP="${HOST_GROUP:-$HOST_USER}"

        echo "HOST_USER ${HOST_USER} HOST_GROUP ${HOST_GROUP}"

        # UID from passwd
        NS_UID_REAL=$(awk -F: -v u="$HOST_USER" '$1==u {print $3}' /host-etc/passwd)

        # GID from group (preferred), with fallback to passwd if /host-etc/group missing
        if [ -f /host-etc/group ]; then
            NS_GID_REAL=$(awk -F: -v g="$HOST_GROUP" '$1==g {print $3}' /host-etc/group)
        else
            # fallback: primary group of a user with name HOST_GROUP
            NS_GID_REAL=$(awk -F: -v u="$HOST_GROUP" '$1==u {print $4}' /host-etc/passwd)
        fi

        echo "NS_UID_REAL ${NS_UID_REAL:-<none>} NS_GID_REAL ${NS_GID_REAL:-<none>}"

        if [ -z "$NS_UID_REAL" ] && [ -z "$NS_GID_REAL" ]; then
            echo "Warning: neither HOST_USER=$HOST_USER nor HOST_GROUP=$HOST_GROUP found in host passwd/group, skipping ID sync" >&2
        else
            #
            # If we have a GID from the host, ensure group 'nsadmin' has that GID.
            #
            if [ -n "$NS_GID_REAL" ]; then
                if getent group nsadmin >/dev/null 2>&1; then
                    groupmod -g "$NS_GID_REAL" nsadmin
                else
                    groupadd -g "$NS_GID_REAL" nsadmin
                fi
            fi

            #
            # If we have a UID from the host, remap user 'nsadmin' to that UID.
            #    - If we also have a new GID, keep primary group 'nsadmin'.
            #    - If no GID was found, just change the UID and keep existing group.
            #
            if [ -n "$NS_UID_REAL" ]; then
                if [ -n "$NS_GID_REAL" ]; then
                    usermod -u "$NS_UID_REAL" -g nsadmin nsadmin
                else
                    usermod -u "$NS_UID_REAL" nsadmin
                fi
            fi
        fi
    fi

    echo "Content of oacs_serverroot: ${oacs_serverroot}"
    ls -l "${oacs_serverroot}"

    LOGDIR="${oacs_logdir:-${oacs_serverroot}/log}"
    mkdir -p "$LOGDIR"
    chown nsadmin:nsadmin "$LOGDIR"
    chmod 2775 "$LOGDIR"
    echo "LOGDIR ${LOGDIR}"
    ls -ld "${LOGDIR}"

    #mkdir -p ${oacs_serverroot}/log
    #mkdir -p ${oacs_serverroot}/www/SYSTEM

    if [ ! -f "${oacs_serverroot}/install.xml" ] ; then
        echo "Using Install file: ${install_file:-openacs-xowf-install.xml}"
        cp "${oacs_serverroot}/${install_file:-openacs-xowf-install.xml}" "${oacs_serverroot}/install.xml"
    fi

    oacs_core_tag="$oacs_tag"
    oacs_packages_tag="$oacs_tag"

    #
    # We have here always a serverroot, but maybe no checked out
    # version of the source code (which might be mounted via
    # "volumes".
    #
    cd  "${oacs_serverroot}" || exit 1
    if [ ! -d "packages" ] ; then
        echo "====== we have no OpenACS packages, install from CVS"
        ls "${oacs_serverroot}"
        #echo "================================= exit"
        #exit

        if [ $alpine = "1" ] ; then
            apk add cvs
        elif [ $debian = "1" ] ; then
            DEBIAN_FRONTEND=noninteractive apt-get -qq install -y cvs
        fi

        cvs -d:pserver:anonymous@cvs.openacs.org:/cvsroot -Q checkout -r "${oacs_core_tag}" acs-core
        if [ ! -d "packages" ] ; then
            #
            # This is for CVS vs. tar checkouts: Move files from openacs-4/* one level up.
            #
            # shellcheck disable=SC2046
            mv $(echo openacs-4/[a-z]*) .
        fi

        #
        # Get content from the installer packages to the install location
        #
        cp "${oacs_serverroot}"/packages/acs-bootstrap-installer/installer/www/*.* "${oacs_serverroot}/www/"
        cp "${oacs_serverroot}"/packages/acs-bootstrap-installer/installer/www/SYSTEM/*.* "${oacs_serverroot}/www/SYSTEM"
        cp "${oacs_serverroot}"/packages/acs-bootstrap-installer/installer/tcl/*.* "${oacs_serverroot}/tcl/"

        #
        # Get more packages
        #
        echo "====== Check out application packages from CVS...."
        cd "${oacs_serverroot}/packages" || exit 1
        cvs -d:pserver:anonymous@cvs.openacs.org:/cvsroot -Q checkout -r "${oacs_packages_tag}" xotcl-all
        cvs -d:pserver:anonymous@cvs.openacs.org:/cvsroot -Q checkout -r "${oacs_packages_tag}" \
            acs-developer-support \
            attachments \
            richtext-ckeditor4 \
            openacs-bootstrap5-theme \
            bootstrap-icons \
            xowf

        #rm /var/www/openacs/install.xml

        if [ "${install_dotlrn}" = "1" ] ; then
            cvs -d:pserver:anonymous@cvs.openacs.org:/cvsroot -Q checkout -r "${oacs_packages_tag}" dotlrn-all
        fi
        echo "====== Check out of from CVS done."
        ls -l "${oacs_serverroot}/packages"

        #
        # Set permissions on server sources and log files
        #
        chown -R nsadmin:nsadmin "${oacs_serverroot}"
        chmod -R g+w "${oacs_serverroot}"

        #
        # Make nsstats available under "/admin/nsstats" on every subsite.
        #
        if [ ! -e  "${oacs_serverroot}"/packages/acs-subsite/www/admin/nsstats.tcl ] ; then
            cp /usr/local/ns/pages/nsstats.* "${oacs_serverroot}"/packages/acs-subsite/www/admin
        fi
    else
        echo "====== Packages are already installed, use existing (external?) installation"
    fi

    #
    # Now we have to check, whether we have to create the database
    #
    echo "====== base-image '$base_image'"
    if [ -e /usr/local/ns/bin/nsdbpg.so ] ; then
        echo "====== we have nsdbpg.so"
    fi

    case $base_image in
        *naviserver-pg*)
            echo "====== Use PostgreSQL"
            db_admin_user=${db_admin_user:-postgres}
            db_dir=/usr
            ;;
        *)
            echo "====== Use Oracle (so far, not configured)"
            db_admin_user=${db_admin_user:-system}
            ;;
    esac

    if [ "$oacs_db_host" = "host.docker.internal" ] ; then
        echo "====== Use the Database on the docker host"
        #
        # We assume, the DB is created and already set up
        #
    else
        echo "====== Use the Database in the container"
        #
        # Configure the database in the DB container
        #
        echo "====== Configuration variables":
        env | sort
        echo "======= DB setup: db_admin_user=$db_admin_user db_dir=$db_dir oacs_db_name=$oacs_db_name oacs_db_host=$oacs_db_host oacs_db_user=$oacs_db_user"

        #cd /tmp
        #set -o errexit

        #echo "====== Checking if oacs_db_user ${oacs_db_user} exists in db..."
        #dbuser_exists=$(su ${db_admin_user} -c "${db_dir}/bin/psql -h ${oacs_db_host} -p ${oacs_db_port} template1 -tAc \"SELECT 1 FROM pg_roles WHERE rolname='${oacs_db_user}'\"")
        #if [ "$dbuser_exists" != "1" ] ; then
        #    echo "====== Creating oacs_db_user ${oacs_db_user}."
        #    su ${db_admin_user} -c "${db_dir}/bin/createuser -h ${oacs_db_host} -p ${oacs_db_port} -s -d ${oacs_db_user}"
        #fi

        #echo "====== Checking if database with name ${oacs_db_name} exists..."
        #db_exists=$(su ${db_admin_user} -c "${db_dir}/bin/psql -h ${oacs_db_host} -p ${oacs_db_port} template1 -tAc \"SELECT 1 FROM pg_database WHERE datname='${oacs_db_name}'\"")
        #if [ "$db_exists" != "1" ] ; then
        #    echo "====== Creating db ${oacs_db_name}..."
        #    su ${db_admin_user} -c "${db_dir}/bin/createdb -h ${oacs_db_host} -p ${oacs_db_port} -E UNICODE ${oacs_db_name}"
        #    su ${db_admin_user} -c "${db_dir}/bin/psql -h ${oacs_db_host} -p ${oacs_db_port} -d ${oacs_db_name} -tAc \"create extension hstore\""
        #fi
    fi


else
    echo "-- Not first container startup --"
fi

for pair in \
    "oacs_clusterSecret cluster_secret" \
    "oacs_parameterSecret parameter_secret"
do
    # Split into two fields (POSIX)
    IFS=' ' read -r var sec <<EOF
$pair
EOF

    file="/run/secrets/$sec"
    if [ -r "$file" ]; then
        val=$(cat "$file")
        export "$var=$val"
        echo "SET $var from $file"
    fi
done

/usr/local/ns/bin/tclsh /scripts/docker-setup.tcl /scripts/docker.config
ls -ltr /scripts/

    LOGDIR="${oacs_logdir:-${oacs_serverroot}/log}"
    mkdir -p "$LOGDIR"
    chown nsadmin:nsadmin "$LOGDIR"
    chmod 2775 "$LOGDIR"
    echo "LOGDIR ${LOGDIR}"
    ls -ld "${LOGDIR}"

echo "-- container-setup-openacs.sh finished --"

# NaviServer container:
#    debian: basic debugging support
#       apt install -y procps iputils-ping iproute2 net-tools bind9-dnsutils file vim
#       apt install -y gcc make libpq-dev autoconf automake m4 zlib1g-dev
#       nsdbpg: make PGINCLUDE=/usr/include/postgresql
#
#    ls -ltr /run/secrets/psql_password
#    vi /usr/local/ns/conf/openacs-config.tcl
#    oacs_httpport=8101 oacs_httpsport=8445 oacs_dbname=oacs-5-10  /usr/local/ns/bin/nsd -f -t /usr/local/ns/conf/openacs-config.tcl -u nsadmin -g nsadmin 2>&1
#
# postgres container:
#     psql -U openacs oacs-5-10
