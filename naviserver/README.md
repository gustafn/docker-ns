# NaviServer Docker Image

This directory contains the **base NaviServer Docker image**.

[![Docker Pulls](https://img.shields.io/docker/pulls/gustafn/naviserver.svg)](https://hub.docker.com/r/gustafn/naviserver)
[![Image Size](https://img.shields.io/docker/image-size/gustafn/naviserver/latest)](https://hub.docker.com/r/gustafn/naviserver)
[![License: MPL-2.0](https://img.shields.io/badge/License-MPL--2.0-blue.svg)](https://mozilla.org/MPL/2.0/)


The image is designed to be used in two complementary ways:

1. **As a standalone, bare-bones NaviServer installation**  
   Suitable for running plain NaviServer applications with a custom Tcl
   configuration file and minimal assumptions.

2. **As the foundation for higher-level containers**  
   Used as the base image for:
   - `naviserver-pg`
   - `naviserver-oracle`
   - `openacs`

Published as:

```
gustafn/naviserver
```

---

## Image variants and tags

### Base distributions

NaviServer images are built on multiple base distributions:

- `*-trixie` (recommended default)
- `*-bookworm`
- `*-alpine`

Examples:
- `latest-trixie`
- `5.0.3-trixie`
- `latest` → alias for the recommended default base

### Versioned tags

Tags follow the scheme:

```
<NaviServer version>-<base>
```

Examples:
- `5.0.3-trixie`
- `4.99.30-alpine`

The `latest` tag always refers to the most recent NaviServer version
on the recommended default base.

---

## Content

The image contains a fairly minimal, plain NaviServer installation
built from:

- NaviServer source code  
  https://github.com/naviserver-project/naviserver/
- Official releases  
  https://sourceforge.net/projects/naviserver/

Currently, the image is built against Tcl 8.6 (and optionally Tcl 9.0),
depending on the selected variant.

### Included Tcl packages

- Tcllib 1.20
- nsf 2.4.0 (XOTcl, NX)
- tDOM 0.9.6
- Thread (version depends on Tcl)

### Included NaviServer modules

- nsauthpam (extra)
- nscgi
- nsdb
- nslog
- nsperm
- nsproxy
- nssmtpd (extra)
- nssock
- nsssl
- nsstats (extra)
- nsudp (extra)
- revproxy (extra)

### High-performance memory allocators

Depending on the base distribution:

- **Debian**: tcmalloc (Google perftools)
- **Alpine**: mimalloc (Microsoft)

The allocator can be activated via `LD_PRELOAD`.

---

## Standalone usage via Docker Compose

The recommended way to run the image is via Docker Compose
(or via Portainer stacks).

Below is the **reference docker-compose configuration** used on Docker Hub,
slightly annotated.

```yaml
services:
  naviserver:
    image: gustafn/naviserver:latest
    restart: unless-stopped

    command: >
      /usr/local/ns/bin/nsd
      -f
      -t ${nsdconfig:-/usr/local/ns/conf/nsd-config.tcl}
      -u nsadmin
      -g nsadmin

    volumes:
      # Host directory exposed inside the container as /var/www
      - ${www:-/var/www}:/var/www

    ports:
      - ${ipaddress:-127.0.0.1}:${httpport:-}:8080
      - ${ipaddress:-127.0.0.1}:${httpsport:-}:8443

    environment:
      - TZ=${TZ:-Europe/Vienna}
      - LD_PRELOAD=${LD_PRELOAD:-}

      # Internal container ports
      - nsd_httpport=8080
      - nsd_httpsport=8443

      # NaviServer layout
      - nsd_home=${home:-/usr/local/ns}
      - nsd_pagedir=${pagedir:-/usr/local/ns/pages}

      # TLS
      - nsd_certificate=${certificate:-/usr/local/ns/etc/server.pem}
      - nsd_vhostcertificates=${vhostcertificates:-/usr/local/ns/etc/certificates}
```

By default, Docker assigns **ephemeral host ports**, which are visible in
Portainer under *Published ports*.

The image includes NaviServer documentation under `/var/www`.

---

## Configuration model (`nsd_*` variables)

The configuration model follows a simple principle:

> **The container provides a stable internal layout.
> The host provides site-specific resources via environment variables and mounts.**

All commonly used configuration knobs are exposed via environment variables,
without the need to edit the Compose file.

### Core variables

| Variable            | Default                             | Meaning                              |
| ------------------- | ----------------------------------- | ------------------------------------ |
| `TZ`                | `Europe/Vienna`                     | Time zone inside the container       |
| `nsdconfig`         | `/usr/local/ns/conf/nsd-config.tcl` | NaviServer config file               |
| `ipaddress`         | `127.0.0.1`                         | IPv4 bind address                    |
| `httpport`          | empty                               | Host HTTP port (ephemeral if empty)  |
| `httpsport`         | empty                               | Host HTTPS port (ephemeral if empty) |
| `pagedir`           | `/usr/local/ns/pages`               | Directory serving pages              |
| `certificate`       | `/usr/local/ns/etc/server.pem`      | TLS certificate                      |
| `vhostcertificates` | `/usr/local/ns/etc/certificates`    | VHost cert directory                 |
| `www`               | `/var/www`                          | Host directory mounted as `/var/www` |

### Example override

```env
httpport=8081
pagedir=/var/www/example.org
certificate=/var/www/certificates/example.org.pem
```

---

## UID / GID mapping

The base `naviserver` image does **not** perform UID/GID mapping.

User mapping and host identity integration are implemented only in
higher-level containers that provide entrypoint/setup scripts, notably:

* `openacs`
* `munin-master`

This keeps the base image simple and predictable.

---

## Custom image variants

Custom variants can be built by adding OS packages via build arguments:

```sh
docker build --no-cache \
  --build-arg "SYSTEM_PKGS=fcgi php83-cgi" \
  -f Dockerfile.naviserver-alpine .
```

This mechanism is used by derived images and advanced setups.

---

## Summary

* This image provides a clean, minimal NaviServer runtime
* It is suitable for standalone use and as a base image
* Configuration is entirely environment-driven
* Higher-level images extend it without breaking the model

---

## License

This project is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL can be obtained from
https://mozilla.org/MPL/2.0/.

Copyright © 2025 Gustaf Neumann
