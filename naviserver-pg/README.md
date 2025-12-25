# NaviServer with PostgreSQL Support

This directory contains the **NaviServer + PostgreSQL client Docker image**.

[![Docker Pulls](https://img.shields.io/docker/pulls/gustafn/naviserver-pg.svg)](https://hub.docker.com/r/gustafn/naviserver-pg)
[![Image Size](https://img.shields.io/docker/image-size/gustafn/naviserver-pg/latest)](https://hub.docker.com/r/gustafn/naviserver-pg)
[![License: MPL-2.0](https://img.shields.io/badge/License-MPL--2.0-blue.svg)](https://mozilla.org/MPL/2.0/)


The image is a **thin extension of the base `gustafn/naviserver` image** and adds
support for PostgreSQL access via the NaviServer module `nsdbpg`.

Published as [gustafn/naviserver-pg](https://hub.docker.com/repository/docker/gustafn/naviserver-pg/)

---

## Purpose and scope

This image is intended for:

- standalone NaviServer applications that require PostgreSQL access
- use as a base image for higher-level containers (notably `openacs`)
- environments where database connectivity should be added without
  otherwise changing the NaviServer runtime model

All general NaviServer behavior (configuration, startup, environment variables)
is inherited from the base image.

---

## Relationship to other images

```

naviserver
└── naviserver-pg
└── openacs

```

- **`naviserver`**  
  Base NaviServer runtime without database drivers

- **`naviserver-pg`**  
  Adds PostgreSQL client libraries and the `nsdbpg` module

- **`openacs`**  
  Adds OpenACS application code, setup logic, and richer configuration

---

## What this image adds

Compared to `gustafn/naviserver`, this image includes:

- PostgreSQL client libraries
- NaviServer database driver:
  - `nsdbpg`
- Build-time tooling to compile and install the module

No additional runtime logic is introduced.

---

## What this image does *not* add

- No OpenACS code
- No automatic database initialization
- No opinionated database configuration
- No UID/GID mapping logic

Database usage is fully controlled by the NaviServer configuration file
and environment variables, just as in the base image.

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

This image can be used directly for NaviServer applications that use PostgreSQL.

Example (simplified):

```sh
docker run --rm \
  -v "$PWD/nsd-config.tcl:/usr/local/ns/conf/nsd-config.tcl:ro" \
  -v /var/run/postgresql:/var/run/postgresql \
  gustafn/naviserver-pg:latest \
  /usr/local/ns/bin/nsd -f -t /usr/local/ns/conf/nsd-config.tcl
```

The PostgreSQL connection parameters (host, port, socket path, database name)
are defined entirely in the NaviServer Tcl configuration.

---

## Database connectivity

The image supports all PostgreSQL connection modes supported by `nsdbpg`,
including:

* TCP connections
* Unix domain sockets
* non-standard ports
* authentication via `.pgpass` or password files

The image itself does **not** impose any policy on how PostgreSQL is accessed.

---

## Build-time configuration

The Dockerfile supports the same build arguments as the base image, plus
those required to build `nsdbpg`.

Commonly used build arguments:

| Argument      | Description                            |
| ------------- | -------------------------------------- |
| `RELEASE_TAG` | Image release tag                      |
| `version_ns`  | NaviServer version                     |
| `system_pkgs` | Extra OS packages (rarely needed here) |

These are typically provided by the component Makefile or the top-level build.

---

## Environment variables

No additional environment variables are introduced by this image.

All relevant runtime configuration uses:

* standard NaviServer configuration files
* the `nsd_*` environment variables documented in `naviserver/README.md`

---

## Usage with Docker Compose and Portainer

This image is commonly used:

* directly, for PostgreSQL-backed NaviServer applications
* indirectly, as the base image for `openacs`

For complete runnable examples, see:

```
examples/
```

In particular:

* `examples/oacs-db-inclusive/`
* `examples/openacs-org/`

---

## Summary

* `naviserver-pg` is a minimal, focused extension of `naviserver`
* It adds PostgreSQL client support via `nsdbpg`
* It preserves the configuration and runtime model of the base image
* Higher-level images build on it without breaking compatibility

---

## License

This project is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL can be obtained from
https://mozilla.org/MPL/2.0/.

Copyright © 2025 Gustaf Neumann
