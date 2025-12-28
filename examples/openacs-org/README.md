# OpenACS.org – production-style Docker stack (example)

This directory contains a **production-style Docker Compose example**
derived from the live OpenACS.org deployment.

It is intentionally more complex than the `oacs-db-inclusive` example and
is meant as a **reference architecture** for real-world OpenACS installations.

> NOTE:  
> This example is **sanitized and snapshot-based**.  
> It does *not* necessarily reflect the current production configuration of
> openacs.org. Site-specific, private, or experimental settings have been
> removed or simplified.

---

## Design goals and use cases

This setup is designed to support:

- long-lived OpenACS installations
- multiple parallel instances on the same host
- testing different NaviServer / Tcl combinations against one OpenACS tree
- production-like deployments with externalized state
- clear separation between *binaries* and *site data*

---

## Key design choices

### 1. Containers hold binaries, not state

All containers are **stateless**:

- OpenACS application code
- NaviServer binaries
- Postfix (mail relay)
- Munin (monitoring)

All **stateful data** lives outside containers:

- OpenACS tree
- logs
- secrets
- database

This allows:
- easy upgrades
- simple backups
- reproducible rebuilds
- fast rollback

---

### 2. External OpenACS tree

The complete OpenACS installation is mounted from the host:

```text
${hostroot}
```

This enables:

* running multiple containers against the same code base
* comparing different NaviServer versions
* development and production sharing the same layout

---

### 3. Database via Unix domain socket

PostgreSQL is accessed via a **domain socket**, not TCP:

* no database port exposed
* lower latency
* reduced attack surface
* supports non-standard database ports

Socket path example:

```text
/tmp/.s.PGSQL.<db_port>
```

This socket is mounted into containers that need DB access.

---

### 4. IPv4 + IPv6 connectivity

The site is reachable via **both IPv4 and IPv6**.

Ports are explicitly bound to:

* an IPv4 address
* an IPv6 address

This makes dual-stack behavior explicit and testable.

---

### 5. Tailored NaviServer configuration

The NaviServer configuration file is **site-specific**:

* multiple domain names
* multiple NaviServer servers
* internal loopback server
* custom module setup
* custom logging layout

The file provided here:

```
openacs.org-config-example.tcl
```

is a **template / example**, not a production snapshot.

---

### 6. Non-standard certificate location

TLS certificates are stored **outside the container**, at a site-specific path:

```text
${hostroot}/etc/
```

The same certificate is reused by:

* NaviServer (HTTPS)
* Postfix (SMTP TLS)

This simplifies certificate management and rotation.

---

### 7. Optional memory optimization

This setup supports preloading Google tcmalloc:

```sh
LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4
```

In combination with:

* `SYSTEM_MALLOC` settings in Tcl
* NaviServer/module configuration

this significantly reduces memory footprint under load.

---

## Container overview

### openacs-org

Main OpenACS / NaviServer container.

* runs the site
* exposes HTTP/HTTPS
* uses a site-specific NaviServer config
* connects to DB via domain socket
* optionally uses tcmalloc

---

### mail-relay

Postfix-based outgoing SMTP relay.

* internal-only (not exposed on host)
* used by `nssmtpd` inside OpenACS
* shares TLS certificate with OpenACS

---

### munin-node

Collects metrics from OpenACS.

* uses NaviServer-provided Munin plugins
* talks to OpenACS over internal network
* can access PostgreSQL via domain socket

---

### munin-master

Generates Munin graphs and static HTML.

* no exposed ports
* writes files only
* output served by OpenACS as `/munin/`

---

## Stack-level environment variables

The following variables are intended as **boilerplate knobs** for
site-specific adaptations.

They are typically set via:

* `.env` files
* Portainer stack variables
* shell environment

### Required variables

| Variable    | Description                                  |
| ----------- | -------------------------------------------- |
| `hostname`  | DNS name of the site (e.g. `openacs.org`)    |
| `hostroot`  | Path to the OpenACS installation on the host |
| `logdir`    | Directory for logs and runtime state         |

---

### Optional but common variables

#### NaviServer configuration

| Variable                | Default                                 | Purpose                                 |
| ----------------------- | --------------------------------------- | --------------------------------------- |
| `nsdconfig`             | `/usr/local/ns/conf/openacs-config.tcl` | Path to site-specific NaviServer config |
| `internal_loopbackport` | `8888`                                  | Internal loopback server port           |

This allows replacing the config file without rebuilding the image.

---

#### Networking (host bindings)

| Variable      | Default     | Purpose              |
| ------------- | ----------- | -------------------- |
| `ipaddress`   | `127.0.0.1` | IPv4 address to bind |
| `ipv6address` | `::1`       | IPv6 address to bind |
| `httpport`    | auto        | External HTTP port   |
| `httpsport`   | auto        | External HTTPS port  |

---

#### TLS / certificates

| Variable      | Default                        | Purpose                   |
| ------------- | ------------------------------ | ------------------------- |
| `certificate` | `${hostroot}/etc/certfile.pem` | TLS cert for HTTPS + SMTP |

---

#### Database

| Variable  | Default     | Purpose                       |
| --------- | ----------- | ----------------------------- |
| `db_user` | `openacs`   | DB user                       |
| `db_host` | `localhost` | DB host (socket-based)        |
| `db_port` | `5432`      | DB port (affects socket name) |

Secrets are always file-based and external.

---

#### Performance / tuning

| Variable      | Default       | Purpose               |
| ------------- | ------------- | --------------------- |
| `LD_PRELOAD`  | empty         | Preload tcmalloc      |
| `system_pkgs` | `imagemagick` | Extra system packages |

---

## Secrets

Secrets are **not stored in this repository**.

Expected files:

```text
${hostroot}/etc/secrets/psql_password.txt
${hostroot}/etc/secrets/cluster_secret.txt
${hostroot}/etc/secrets/parameter_secret.txt
```

They are mounted via Docker secrets and read by startup scripts.

---

## Files in this directory

* `docker-compose.yml`
  Full stack definition

* `openacs.org-config-example.tcl`
  Sanitized example of a site-specific NaviServer configuration

* `.env.example`
  This stack is designed to be configured via a `.env` file, like the specified one.


   To get started:

   ```sh
   cp .env.example .env
   ```

   Adjust the values to match your host paths, IP addresses, and site name.
   No secrets have to be stored in the .env file; all credentials are provided via
   external secret files mounted into the containers.

---

## When to use this example

Use this setup if you want:

* a production-grade OpenACS deployment
* maximum flexibility for upgrades and testing
* strong separation between infrastructure and application state

For a minimal, self-contained setup, see:

```
examples/oacs-db-inclusive/
```

---

## Final notes

This example reflects **operational experience** rather than minimalism.
It is meant to be adapted, not copied verbatim.

Treat it as a toolbox and reference, not a prescription.

---

## License

This project is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL can be obtained from
https://mozilla.org/MPL/2.0/.

Copyright © 2025 Gustaf Neumann
