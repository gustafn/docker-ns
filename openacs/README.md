# OpenACS Docker Image

This directory contains the **OpenACS runtime image** based on NaviServer.
It is designed to be used both standalone and as part of larger stacks
(e.g. via Docker Compose or Portainer).

[![Docker Pulls](https://img.shields.io/docker/pulls/gustafn/openacs.svg)](https://hub.docker.com/r/gustafn/openacs)
[![Image Size](https://img.shields.io/docker/image-size/gustafn/openacs/latest)](https://hub.docker.com/r/gustafn/openacs)
[![License: MPL-2.0](https://img.shields.io/badge/License-MPL--2.0-blue.svg)](https://mozilla.org/MPL/2.0/)

The image provides:

- OpenACS application code and installation logic
- NaviServer runtime
- Database initialization and upgrade support
- Flexible configuration via environment variables
- Support for multiple base distributions and NaviServer versions
  
The image is based on [`gustafn/naviserver-pg`](../naviserver-pg/README.md) and contains the Tcl packages and NaviServer modules as provided by this container.

The OpenACS container image includes the NaviServer **letsencrypt** module.
A sample (disabled) configuration snippet is shipped with the `openacs-org` example.
Enable it by uncommenting the letsencrypt section and providing the required settings
(API, key type, domains/SANs, and HTTP challenge reachability).

Source repositories:
- [NaviServer](https://github.com/naviserver-project)
- [OpenACS](https://github.com/openacs)

The image is published as [gustafn/openacs](https://hub.docker.com/repository/docker/gustafn/openacs/)

---

## Filesystem layout and design principles

The OpenACS container follows a **normalized internal filesystem layout**.

All externally provided paths (bind mounts or named volumes) are mapped into a
**fixed internal directory structure**. OpenACS, NaviServer, and all helper
scripts only ever reference **internal paths**, never host paths.

This design:

* avoids host-specific paths in configuration files
* simplifies upgrades and container restarts
* works reliably with Docker volumes, bind mounts, and NFS
* enables future features such as automated certificate renewal

The normalized filesystem layout only affects how external paths are mapped
into the container and does not change OpenACS or NaviServer semantics.


### Canonical internal paths

Inside the container, the following paths are fixed:

| Purpose | Internal path |
|--------|---------------|
| OpenACS server root | `/var/www/openacs` |
| Configuration files | `/var/www/openacs/etc` |
| Application data / content repository | `/var/www/openacs` |
| Logs | `/var/www/openacs/log` |
| Managed TLS certificates | `/var/lib/naviserver/certificates` |
| Secrets | `/run/secrets` |

For stateful components (logs, certificates, secrets, data), the container
distinguishes between:

* **optional internal storage**, provided via named Docker volumes (default)
* **externally managed paths**, provided explicitly by the user via bind mounts

If no external path is specified, the container uses a named volume and assumes
that it owns the lifecycle of the data stored there (including permissions and
future automated management).

If an external path is provided (e.g. `certificatesdir`, `logdir`, `secretsdir`),
the container assumes that the user manages this data and disables any implicit
assumptions about creation, renewal, or cleanup.

External directories are always mounted to these locations.
Host paths never appear in OpenACS or NaviServer configuration files.

---

## Runtime behavior

On container startup, the image typically performs:

1. Optional setup via `/scripts/container-setup-openacs.sh`
2. Database connectivity checks
3. Optional OpenACS installation or upgrade
4. NaviServer startup

The exact behavior depends on the provided environment variables and mounted
volumes.

---

## Required runtime inputs

At minimum, the container needs:

- Database connection information
- A writable OpenACS server root (usually `/var/www/openacs`)
- A database password file

These are typically provided via environment variables and volumes.

---

## Environment variables

The following environment variables are recognized by the OpenACS container.

### General settings

The canonical internal server root is:

```
/var/www/openacs
```

This value should not be changed. External server roots must be bind-mounted to
this location.

| Variable | Default | Description |
|--------|--------|-------------|
| `TZ` | unset | Time zone (e.g. `Europe/Vienna`) |
| `oacs_server` | `openacs` | Logical OpenACS server name |
| `oacs_hostname` | `localhost` | Hostname used by OpenACS |
| `oacs_serverroot` | `/var/www/openacs` | OpenACS server root directory |
| `oacs_tag` | unset | Logical instance tag (useful for parallel setups) |

---

### HTTP / HTTPS configuration

| Variable | Default | Description |
|--------|--------|-------------|
| `oacs_httpport` | `8080` | Internal HTTP port |
| `oacs_httpsport` | `8443` | Internal HTTPS port |
| `oacs_ipaddress` | `::` | IP address NaviServer binds to |
| `oacs_loopbackport` | `8888` | Internal loopback port |

> Port publishing to the host is handled at the Docker Compose / stack level.

---

### Database connection

| Variable | Default | Description |
|--------|--------|-------------|
| `oacs_db_name` | `openacs` | Database name |
| `oacs_db_user` | `openacs` | Database user |
| `oacs_db_host` | `localhost` | Database host |
| `oacs_db_port` | `5432` | Database port |
| `oacs_db_passwordfile` | `/run/secrets/psql_password` | File containing DB password |

The password file must exist at container startup.

---

## Configuration file (`nsdconfig`)

If `nsdconfig` is set, it is interpreted as a **relative filename under**:

```
/var/www/openacs/etc/
```

Example:

```
nsdconfig=openacs.org-config.tcl
```

This resolves internally to:

```
/var/www/openacs/etc/openacs.org-config.tcl
```

If `nsdconfig` is unset, the legacy default
`/usr/local/ns/conf/openacs-config.tcl` is used.

---

## User and permissions model

All OpenACS and NaviServer processes run as:

```
nsadmin:nsadmin
```

To avoid permission issues on bind-mounted directories, the container supports
UID/GID alignment with the host:

```yaml
environment:
  HOST_USER: nsadmin
  HOST_GROUP: nsadmin
```

When enabled, files created inside the container remain writable on the host.
This is especially important for NFS and shared filesystems.


---

### Cluster / secrets

| Variable | Default | Description |
|--------|--------|-------------|
| `oacs_clusterSecret` | unset | Cluster secret (for multi-node setups) |
| `oacs_parameterSecret` | unset | Secret for encrypted parameters |

Leave unset for single-node setups.

---

### Package installation (runtime)

| Variable | Default | Description |
|--------|--------|-------------|
| `system_pkgs` | unset | Extra system packages installed at build or startup |

Example:
```sh
system_pkgs="imagemagick poppler-utils"
```

---

## TLS Certificates & `certificatesdir`

The OpenACS container includes support for HTTPS/TLS by managing a certificate file that NaviServer will use for SSL termination (e.g., on `oacs_httpsport`). You can control this behavior using the following environment variables and volume mappings.

### Default Behavior

By default, if no certificate is provided, the entrypoint will
generate a **self-signed certificate** for the hostname
(`oacs_hostname`) and store it in the **managed certificate
store** following the following naming convention:

```
/var/lib/naviserver/certificates/<hostname>.pem
```

### `certificate`

The variable `certificate` specifies a **relative PEM filename** under:

```
/var/www/openacs/certificates/
```

Example:

```
certificate=openacs.org.pem
```

Seed certificate lookup order:

1. `/var/www/openacs/certificates/<certificate>`
2. legacy fallback: `/var/www/openacs/etc/<certificate>`

If a readable seed certificate is found, it is copied into the managed
certificate store. If not, a self-signed certificate may be generated (unless
external certificate management is enabled).

### `certificatesdir`

By default, a writable named volume is mounted at:

```
/var/lib/naviserver/certificates
```

This directory is used for:

* generated certificates
* copied seed certificates
* automated renewal (future feature)

If `certificatesdir` is set, the directory is treated as **externally managed**:

```yaml
volumes:
  - /path/on/host/certificates:/var/lib/naviserver/certificates
```

In this mode, certificates must already exist and no automatic generation or
renewal is assumed. This mirrors the behavior of `/run/secrets`.


### Summary of Variables

| Variable                          | Purpose                                                             |
| --------------------------------- | ------------------------------------------------------------------- |
| `oacs_hostname`                   | Hostname used for certificate CN/SAN and default PEM filename.      |
| `oacs_certificate`                | Optional explicit full path to a certificate PEM (key+cert).        |
| `certificatesdir`                 | If set and non-empty, enables external certificate management mode. |
| `oacs_certificates` (volume name) | Default named volume for storing generated or copied certificates.  |

---

### Logging

| Variable | Default | Description |
|--------|--------|-------------|
| `logdir` | `/var/www/openacs/log` | Log directory |

`logdir` specifies the storage backend for logs.

It can be either:

* a named Docker volume (default)
* a host directory (bind mount)

In all cases, logs are written internally to:

```
/var/www/openacs/log
```

Example:

```yaml
volumes:
  - ${logdir:-oacs_log}:/var/www/openacs/log
```


---

## Volumes and files

Commonly used paths:

| Path                 | Purpose                               |
| -------------------- | ------------------------------------- |
| `/var/www/openacs`   | OpenACS server root and filestore     |
| `/run/secrets`       | Secrets directory                     |
| `/usr/local/ns/conf` | NaviServer configuration              |
| `/usr/local/ns/log`  | NaviServer logs (depending on config) |

---

## Installation and upgrades

The image supports:

* Fresh OpenACS installations
* Upgrades of existing installations
* Reuse of an existing server root

Typical patterns:

* Bind-mount an existing `/var/www/openacs`
* Provide an installation XML (e.g. `openacs-plain-install.xml`)
* Allow the startup scripts to detect and act accordingly

Details of the installation flow are implemented in:

```
scripts/container-setup-openacs.sh
```

---

## Running multiple instances

Multiple OpenACS instances can run in parallel by:

* Using different container names / stack names
* Using different `oacs_server` / `oacs_tag` values
* Mounting separate server roots and secrets

This is commonly used to test multiple NaviServer or OpenACS versions side by side.

---

## Integration with Docker Compose and Portainer

This image is designed to be consumed by:

* Docker Compose stacks
* Portainer stacks

See the example stacks under:

```
examples/
```

for fully working configurations and stack-level documentation.

---

## Troubleshooting

* Check logs:

  ```sh
  docker logs <openacs-container>
  ```
* Verify database connectivity
* Inspect `/SYSTEM/success.tcl` for application health

---

## Scope

This README documents **image-level behavior and configuration**.

Stack-level concerns (ports, volumes, secrets, orchestration) are documented
with the corresponding examples.

For complete runnable setups, see:

```
examples/oacs-db-inclusive/
examples/openacs-org/
```

---

## License

This project is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL can be obtained from
https://mozilla.org/MPL/2.0/.

Copyright © 2025 Gustaf Neumann
