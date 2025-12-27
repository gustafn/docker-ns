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

Source repositories:
- [NaviServer](https://github.com/naviserver-project)
- [OpenACS](https://github.com/openacs)

---

## Image overview

Published as [gustafn/openacs](https://hub.docker.com/repository/docker/gustafn/openacs/)


### Supported tags

- `latest-trixie` (recommended default)
- `latest-bookworm`
- `latest-alpine`
- `latest` → alias to the recommended default base

Versioned tags follow the same scheme, e.g.:

- `5.0.3-trixie`
- `5.0.3` → alias to `5.0.3-trixie`

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

By default, if no certificate is provided, the entrypoint will generate a **self-signed certificate** for the hostname (`oacs_hostname`) and store it under the default certificates directory:

```
/var/www/openacs/certificates/${oacs_hostname}.pem
```

This directory is exposed as a persistent volume so the certificate will survive container restarts:

```yaml
services:
  openacs:
    volumes:
      - ${certificatesdir:-oacs_certificates}:/var/www/${service:-openacs}/certificates
```

This default (`oacs_certificates`) is a named volume that persists the generated self-signed certificate and supports automated renewal workflows (e.g., via Let’s Encrypt tooling that might be integrated later).

### Providing Your Own Certificate

If you have an existing certificate (combined key+cert in one PEM file), you can specify it via the `oacs_certificate` environment variable:

```yaml
services:
  openacs:
    environment:
      oacs_certificate: "/run/secrets/my_cert.pem"
```

* When **no `certificatesdir` is set** (internal mode), the entrypoint will **copy the provided certificate into the default certdir** (overwriting or seeding) before starting NaviServer. This ensures the certificate is placed in the same writable volume that renewal tooling expects.

### External Certificate Management (`certificatesdir`)

When you explicitly provide a `certificatesdir` environment variable (or bind a host directory to it), this signals that the certificates are **managed externally** (outside the container) and should not be copied or generated automatically.

Example compose snippet:

```yaml
services:
  openacs:
    environment:
      certificatesdir: "/run/secrets/openacs_certs"
      oacs_hostname: "example.com"
      oacs_certificate: "/run/secrets/example.com.pem"
    volumes:
      - /path/on/host/certs:/run/secrets/openacs_certs
```

In this mode:

* No certificate copying is performed.
* The container expects the certificate to already exist and be readable at the path you specify.
* Automated generation of self-signed certificates *is disabled* by default (you can opt in via `ns_allow_self_signed=1` if needed).
* This mode is useful when certificates are managed externally (e.g., corporate PKI, Let’s Encrypt on the host, or a secrets manager).

If the certificate is missing or unreadable in external mode (and self-signed generation is not permitted), the startup will fail to prevent unclear HTTPS behavior.

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
| `oacs_logroot` | `/var/www/openacs/log` | Log directory |

Ensure this path is writable and persistent if logs should survive restarts.

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
