# NaviServer with Oracle Support

This directory contains the **NaviServer + Oracle client Docker image**.

[![Docker Pulls](https://img.shields.io/docker/pulls/gustafn/naviserver-oracle.svg)](https://hub.docker.com/r/gustafn/naviserver-oracle)
[![Image Size](https://img.shields.io/docker/image-size/gustafn/naviserver-oracle/latest)](https://hub.docker.com/r/gustafn/naviserver-oracle)
[![License: MPL-2.0](https://img.shields.io/badge/License-MPL--2.0-blue.svg)](https://mozilla.org/MPL/2.0/)



The image is a **thin extension of the base `gustafn/naviserver` image** and adds
support for Oracle database access via the NaviServer module `nsdboracle`.

Published as:

```
gustafn/naviserver-oracle
```

---

## Purpose and scope

This image is intended for:

- standalone NaviServer applications that require Oracle database access
- use as a base image for higher-level containers
- environments where Oracle connectivity is needed without changing the
  overall NaviServer runtime and configuration model

All general NaviServer behavior (configuration, startup, environment variables)
is inherited unchanged from the base image.

---

## Relationship to other images

```
naviserver
├── naviserver-pg
└── naviserver-oracle
└── (application-specific images)
```

- **`naviserver`**  
  Base NaviServer runtime without database drivers

- **`naviserver-oracle`**  
  Adds Oracle client libraries and the `nsdboracle` module

- **Application images**  
  Extend this image with application-specific logic

---

## What this image adds

Compared to `gustafn/naviserver`, this image includes:

- Oracle client libraries (Instant Client)
- NaviServer database driver:
  - `nsdboracle`
- Build-time tooling to compile and install the module

No additional runtime behavior is introduced.

---

## What this image does *not* add

- No application code
- No database schema management
- No automatic database initialization
- No UID/GID mapping logic

All database usage is controlled entirely by the NaviServer configuration.

---

## Tags and versions

Tags follow the same scheme as the base image:

```
<NaviServer version>-<base>
```

Examples:

- `latest-trixie`
- `5.0.3-trixie`
- `4.99.30-alpine`

The `latest` tag refers to the most recent NaviServer version on the
recommended default base.

---

## Standalone usage

This image can be used directly for NaviServer applications that use Oracle.

Example (simplified):

```sh
docker run --rm \
  -v "$PWD/nsd-config.tcl:/usr/local/ns/conf/nsd-config.tcl:ro" \
  -e ORACLE_HOME=/opt/oracle/instantclient \
  -e LD_LIBRARY_PATH=/opt/oracle/instantclient \
  gustafn/naviserver-oracle:latest \
  /usr/local/ns/bin/nsd -f -t /usr/local/ns/conf/nsd-config.tcl
```

Connection details (TNS name, credentials, host, port) are specified in
the NaviServer Tcl configuration file.

---

## Oracle client considerations

Oracle support requires:

* compatible Oracle Instant Client libraries
* correct `LD_LIBRARY_PATH`
* matching architecture (amd64 / arm64, where available)

The exact Instant Client version is chosen at build time.

---

## Build-time configuration

The Dockerfile supports the same build arguments as the base image, plus
arguments required to install the Oracle client and build `nsdboracle`.

Commonly used build arguments:

| Argument      | Description                       |
| ------------- | --------------------------------- |
| `RELEASE_TAG` | Image release tag                 |
| `version_ns`  | NaviServer version                |
| `system_pkgs` | Extra OS packages (rarely needed) |

These are typically provided by the component Makefile.

---

## Environment variables

No additional environment variables are introduced by this image.

All runtime configuration is inherited from:

* the base `naviserver` image
* the NaviServer Tcl configuration file

---

## Usage with Docker Compose and Portainer

This image is used in the same way as `naviserver` and `naviserver-pg`.

---

## Summary

* `naviserver-oracle` is a focused extension of `naviserver`
* It adds Oracle client support via `nsdboracle`
* It preserves the runtime and configuration model of the base image
* Application images build on it without special handling


---

## License

This project is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL can be obtained from
https://mozilla.org/MPL/2.0/.

Copyright © 2025 Gustaf Neumann
