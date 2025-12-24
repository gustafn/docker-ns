# NaviServer and OpenACS Docker Images

This repository provides a modular set of Docker images and example stacks for
running **OpenACS** on top of **NaviServer**, together with supporting services
(PostgreSQL, Munin, mail relay).

The repository is structured to support:

- multiple base distributions (`trixie`, `bookworm`, `alpine`)
- multiple NaviServer versions (including parallel testing)
- local development builds and multi-arch `buildx` pushes
- reproducible example stacks using Docker Compose or Portainer

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
├── naviserver-pg/           # NaviServer with PostgreSQL client support
├── naviserver-oracle/       # NaviServer with Oracle client support
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

Images are published under the `gustafn/*` namespace on Docker Hub.

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

This example is intended for advanced setups and testing scenarios.

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

The top-level `Makefile` orchestrates all builds.

Typical commands:

```sh
# Build all components (local build)
make

# Build only OpenACS
make build-openacs

# Multi-arch build & push (default base)
make buildx-openacs

# Versioned build
make VERSION_NS=5.0.3 RELEASE_TAG=5.0.3 buildx-openacs

# Local development build (adds -local tag, no push)
make LOCAL_TAG=-local build-openacs
```

Build stamps ensure images are rebuilt only when their ingredients change.

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
