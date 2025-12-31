# NaviServer and OpenACS Docker Images

This repository provides a modular set of Docker images and example stacks for
running **OpenACS** on top of **NaviServer**, together with supporting services
(PostgreSQL, Munin, mail relay).

The repository is structured to support:

- multiple base distributions (`trixie`, `bookworm`, `alpine`)
- multiple NaviServer versions (including parallel testing)
- local development builds and multi-arch `buildx` pushes
- reproducible example stacks using Docker Compose or Portainer


Source repositories:
- [NaviServer](https://github.com/naviserver-project)
- [OpenACS](https://github.com/openacs)

---

## Repository structure

```
.
├── examples/                # Runnable docker-compose examples
│   ├── oacs-db-inclusive/   # Self-contained OpenACS + PostgreSQL stack
│   └── openacs-org/         # openacs.org-style deployment (external data)
│
├── openacs/                 # OpenACS image (runtime + setup scripts)
├── naviserver/              # Base NaviServer image
├── naviserver-pg/           # NaviServer image with PostgreSQL client support
├── naviserver-oracle/       # NaviServer image with Oracle client support
├── munin-master/            # Munin master image
├── munin-node/              # Munin node image (OpenACS-aware)
├── mail-relay/              # Postfix-based mail relay
│
├── scripts/                 # Shared helper scripts (synced into images)
├── Makefile                 # Top-level build / buildx orchestration
└── README.md                # (this file)

```

---

## Docker images and tags

These 7 ready-to-use images are published under the `gustafn/*` namespace on Docker Hub ([https://hub.docker.com/repositories/gustafn](https://hub.docker.com/repositories/gustafn)). Each of these images is provided as a mostly independent subdirectory with its own Makefile.

### Tagging policy

For each component:

- Base-specific tags:
  - `latest-trixie`
  - `latest-bookworm`
  - `latest-alpine`
- Alias tag:
  - `latest` → points to the recommended default base (currently `trixie`)
- Versioned tags:
  - e.g. `5.0.3-trixie`
  - alias `5.0.3` → points to the default base

The registry state (manifest digests) is authoritative.  
Docker Hub’s web UI may lag behind after pushes.

---

## Examples

Runnable examples are provided under `examples/`.

### A) `examples/oacs-db-inclusive`

A **self-contained OpenACS stack**:

- OpenACS container
- PostgreSQL container
- Named volumes for database, filestore, and secrets

Works out of the box with:

```sh
cd examples/oacs-db-inclusive
docker compose up -d
```

See:

```
examples/oacs-db-inclusive/README.md
```

for full documentation of stack-level parameters and tailoring options.

### B) `examples/openacs-org` (planned / evolving)

An **openacs.org-style deployment**:

* All binaries inside containers
* Configuration, scripts, logs, and database externalized
* Supports running multiple OpenACS / NaviServer versions in parallel

This example is mirrored after the [openacs.org site](https://openacs.org) and contains in addition of the `openacs` image a `mail-relay` for sending mails, a preconfigured munin monitoring infrastructure (`munin-node` and `munin-master`), and automated certificate renewal via the `letsencrypt` NaviServer module. The configuration contains 4 virtual servers serviced by the same NaviServer instance.

This example is intended to provide a reference for advanced setups and testing scenarios.

---

## Configuration documentation

Configuration is documented at two levels:

### Stack-level (examples)

Each example directory contains a `README.md` describing:

* stack-level environment variables
* volumes and bind mounts
* common adaptation patterns

### Image-level (components)

Each component directory (`openacs/`, `naviserver/`, etc.) contains a `README.md`
with:

* full environment variable reference
* defaults and behavior
* interactions between variables

This avoids duplication and keeps example files readable.

---

## Building the images

The top-level `Makefile` orchestrates all Docker image builds in this repository.

Typical commands:

```sh
# Build all components (local build)
make

# Build only OpenACS
make build-openacs
```

### Local development builds (recommended for modifications)

If you modify **any** of the following:

* shell scripts
* Dockerfiles
* configuration templates
* docker-compose examples
* container setup logic

you should **always build a local image** using the `-local` tag.

```sh
# Local development build (adds -local tag, no push)
make LOCAL_TAG=-local build-openacs
```

This produces an image such as:

```text
gustafn/openacs:latest-local
```

or (with explicit versions):

```text
gustafn/openacs:5.0.3-local
```

You can then reference this image safely in your own `docker-compose.yml`:

```yaml
services:
  openacs:
    image: gustafn/openacs:latest-local
```

This ensures:

* your changes are actually used
* no accidental overwriting of published images
* reproducible local testing

---

### Multi-architecture builds (`buildx`)

```sh
# Multi-arch build & push (default base)
make buildx-openacs
```

**Important**
`buildx` builds **and pushes** images to Docker Hub.

This requires:

* write permissions to the `gustafn/*` repositories
* a logged-in Docker client (`docker login`)
* intentional use

If you do **not** have push rights, this command will fail.

---

### Versioned builds

```sh
# Versioned build
make VERSION_NS=5.0.3 RELEASE_TAG=5.0.3 buildx-openacs
```

This results in tags such as:

```text
gustafn/openacs:5.0.3
gustafn/openacs:5.0.3-trixie
```

These tags are intended for **published, reproducible releases** only.

---

### Summary: which build should I use?

| Use case                        | Recommended build                     |
| ------------------------------- | ------------------------------------- |
| Testing local changes           | `make LOCAL_TAG=-local build-openacs` |
| Developing container logic      | `-local` tag                          |
| Running examples from this repo | published tags (`latest`, versioned)  |
| Publishing official images      | `buildx-*` (with push rights)         |

As a rule of thumb:

> **If you changed something locally, never rely on `latest`.
> Always build and use a `-local` image.**

---

### Notes on image naming

The final image tag is composed from:

* base name: `gustafn/openacs`
* optional version: `5.0.3`
* optional distro suffix: `-trixie`, `-bookworm`, …
* optional local marker: `-local`

Examples:

```text
gustafn/openacs:latest
gustafn/openacs:latest-local
gustafn/openacs:5.0.3
gustafn/openacs:5.0.3-local
```

These tags can be freely mixed in `docker-compose.yml` depending on your workflow.

---

## Using Portainer

All examples can be deployed via **Portainer** as Docker Compose stacks.

Recommended approach:

1. In Portainer: **Stacks → Add stack**
2. Paste (or reference via Git) the example `docker-compose.yml`
3. Optionally define stack-level environment variables
4. Deploy

Notes:

* Named volumes are created automatically by Portainer
* Secret files (e.g. `/run/secrets/psql_password`) must be created once, just as
  with plain Docker Compose
* Running multiple instances is straightforward using different stack names

Each example README contains a short Portainer-specific section.

---

## Notes on Docker Hub status vs registry truth

Docker Hub’s web UI and metadata API can lag behind after multi-arch pushes.

For authoritative checks, prefer:

```sh
docker buildx imagetools inspect gustafn/openacs:latest
docker manifest inspect gustafn/openacs:latest
```

A helper script (`hub-verify-tags.sh`) is provided to compare tags reliably.

---

## Scope and philosophy

This repository focuses on:

* clarity over magic
* explicit configuration with sensible defaults
* enabling experimentation (multiple versions, parallel stacks)
* keeping operational knowledge in version-controlled documentation

Contributions and feedback are welcome.

---

## License

This project is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL can be obtained from
https://mozilla.org/MPL/2.0/.

Copyright © 2025 Gustaf Neumann
