# OpenACS – DB-inclusive example (oacs-db-inclusive)

This example runs a complete, self-contained OpenACS stack using:

- **OpenACS container**: `gustafn/openacs:latest` (defaults to the recommended base via the `latest` alias)
- **PostgreSQL container**: `postgres:18`

It is intended as a *minimal* and *reproducible* starting point.  
It works without providing any stack-level environment variables.

---

## Quick start

From this directory:

```sh
docker compose up -d
```

Check health / startup:

```sh
docker compose ps
docker compose logs -f openacs
docker compose logs -f postgres
```

Stop:

```sh
docker compose down
```

Remove persistent data (named volumes):

```sh
docker compose down -v
```

Connect to the Database to Run SQL Commands

When installing the system with `oacs-5-10` as database name (default) and `openacs` as database user (default) then

- Open a shell to the postgres container (or use docker run ... or docker exec ...)
- `psql --username openacs --dbname oacs-5-10`


---

## What this stack creates

Named volumes (persistent):

* `db_data`   - PostgreSQL data
* `oacs_data` - OpenACS tree; when `$hostroot` is set: OpenACS server root on the host
* `oacs_log`  - OpenACS log directory; when `$logdir` is set: log directory on the host
* `oacs_certificates` - OpenACS certificates directory; when `secretsdir` is set: certificates directory on the host
* `oacs_secrets` - OpenACS secrets directory; when `secretsdir` is set: secretsdir directory on the host

Notes:

* The OpenACS container expects the database password via `oacs_db_passwordfile=/run/secrets/psql_password`.
* The Postgres container reads `POSTGRES_PASSWORD_FILE=/run/secrets/psql_password`.
* The secret is stored in a named volume by default (see “Secrets” below).

---

## Stack-level parameters (optional)

These parameters can be set via environment variables (shell or a `.env` file placed next to `docker-compose.yml`).

### General

* `TZ`
  Default: `Europe/Vienna`
  Time zone used by containers.


* `hostname`
  Default: `localhost`
  Sets OpenACS hostname (`oacs_hostname`).

* `nsdconfig`
  Default: `/usr/local/ns/conf/openacs-config.tcl`
  Path to the NaviServer config file used for startup.

### Database settings

* `db_user`
  Default: `openacs`

* `db_host`
  Default: `postgres`
  Hostname of the Postgres service in this compose file.

* `db_port`
  Default: `5432`

* `db_name`
  Default: `oacs-5-10`
  Used as PostgreSQL database name.


### Ports and bind addresses

The OpenACS container exposes internal ports **8080** (HTTP) and **8443** (HTTPS).

You can optionally control the host bind addresses and host ports:

* `ipaddress`
  Default: `127.0.0.1`
  IPv4 bind address for published ports.

* `ipv6address`
  Default: `::1`
  IPv6 bind address for published ports.

* `httpport`
  Default: empty (Docker chooses an ephemeral host port)
  Host port mapped to container port 8080.

* `httpsport`
  Default: empty (Docker chooses an ephemeral host port)
  Host port mapped to container port 8443.

Examples:

Bind to loopback with fixed ports:

```sh
ipaddress=127.0.0.1 ipv6address=::1 httpport=8080 httpsport=8443 docker compose up -d
```

Bind to a public IPv4 address:

```sh
ipaddress=91.114.61.250 httpport=80 httpsport=443 docker compose up -d
```

Bind to a public IPv6 address:

```sh
ipv6address=2001:db8::123 httpport=80 httpsport=443 docker compose up -d
```

---

## Secrets

By default, secrets are provided via a *named volume* mounted at `/run/secrets`.

* Default volume name: `oacs_secrets`
* You can override the volume name via `secretsdir` (for convenience in multi-instance setups).

The file expected by both services is:

* `/run/secrets/psql_password`

How to set it up:

1. Start once to create the named volume:

```sh
docker compose up -d postgres
docker compose down
```

2. Put a password file into the named volume (one-time):

```sh
# Example: create a helper container to write into the volume
docker run --rm -v oacs_secrets:/run/secrets alpine sh -c 'umask 077; echo "change-me" > /run/secrets/psql_password'
```

(Use a strong password; this example is intentionally minimal.)

---

## Tailoring and common adaptations

### Use a custom `openacs-config.tcl`

Bind mount your config into the container:

```yaml
services:
  openacs:
    volumes:
      - ./openacs-config.tcl:/usr/local/ns/conf/openacs-config.tcl:ro
```

Then either keep the default `nsdconfig` (it already points there) or override it explicitly.

### Use a custom install.xml

The OpenACS entrypoint can consume an installation XML (see image documentation).
A typical approach is to bind-mount your chosen file to `${oacs_serverroot:-/var/www/openacs}/install.xml` (or whatever your setup scripts expect).

### Keep data outside Docker volumes

For development or backups you may prefer bind mounts:

```yaml
services:
  openacs:
    volumes:
      - ./data/oacs:${oacs_serverroot:-/var/www/openacs}
  postgres:
    volumes:
      - ./data/pg:/var/lib/postgresql/data/18/docker
```

(Adjust ownership/permissions to match the container user expectations.)

### Run multiple instances in parallel

Use a distinct `service` name and separate volumes/secrets names:

```sh
service=oacs-a secretsdir=oacs_a_secrets docker compose up -d
```

For parallel stacks from the same directory, consider using a project name:

```sh
docker compose -p oacs_a up -d
docker compose -p oacs_b up -d
```

---

## Where to find detailed OpenACS container configuration

This example documents only **stack-level** knobs.

For the full list of OpenACS runtime environment variables (`oacs_*`), see:

* `openacs/README.md` in this repository

---

Good point — Portainer is very commonly used with these setups, and it fits naturally at the **example** level.

### Where to add it

Add a **short, self-contained section** near the end of
`examples/oacs-db-inclusive/README.md`, *after* “Tailoring and common adaptations” and *before* “Troubleshooting”.

That keeps:

* core Docker Compose usage first
* Portainer as an optional orchestration/UI layer
* troubleshooting still last

---

## Using this example with Portainer

This stack can be deployed and managed via **Portainer** without modifications.

### Recommended approach: Portainer stack (Docker Compose)

1) In Portainer, go to **Stacks → Add stack**
2) Choose **Web editor** or **Git repository**
3) Paste (or reference) `docker-compose.yml` from this directory
4) (Optional) Define stack-level environment variables in Portainer’s **Environment variables** section
5) Deploy the stack

The example works without defining any environment variables.

---

### Environment variables in Portainer

All stack-level parameters described above can be set in Portainer’s
**Environment variables** section instead of a `.env` file.

Common examples:

| Variable | Example value |
|--------|---------------|
| `service` | `oacs-5-10` |
| `hostname` | `openacs.example.org` |
| `ipaddress` | `127.0.0.1` |
| `httpport` | `8080` |
| `httpsport` | `8443` |

Portainer will substitute these values exactly like `docker compose`.

---

### Named volumes and secrets in Portainer

This example uses named volumes by default:

- `db_data`
- `oacs_data`
- `oacs_secrets`

When deployed via Portainer:
- These volumes are created automatically on first deployment
- The secret file `/run/secrets/psql_password` must still be created manually (once)

You can create the secret file using a temporary helper container from Portainer:

1) Go to **Containers → Add container**
2) Use image `alpine`
3) Enable **Interactive & TTY**
4) Command:
   ```sh
   sh -c 'umask 077; echo "change-me" > /run/secrets/psql_password'
   ```
5. Add a volume mapping:
   * Volume: `oacs_secrets`
   * Container path: `/run/secrets`   
6. Start the container once, then remove it

---

### Logs and health status

Portainer provides:

* Per-container logs (`Containers → openacs → Logs`)
* Healthcheck status (visible in container list)
* Restart controls

These are equivalent to:

```sh
docker compose logs -f openacs
docker compose ps
```

---

### Multiple instances with Portainer

To run multiple OpenACS instances in parallel:

* Use **different stack names** in Portainer
* Use distinct values for:

  * `service`
  * `secretsdir` (if overridden)
  * host bind ports (`httpport`, `httpsport`)

Portainer keeps stacks isolated by project name, making this a natural fit for
testing multiple OpenACS / NaviServer versions side by side.

---

## Troubleshooting

* **Check healthchecks**

  ```sh
  docker compose ps
  ```

* **Inspect logs**

  ```sh
  docker compose logs -f openacs
  docker compose logs -f postgres
  ```

* **Database readiness**

  ```sh
  docker compose exec postgres pg_isready -U "${db_user:-openacs}" --dbname "${service:-oacs-5-10}"
  ```

* **OpenACS success endpoint**

  ```sh
  curl -s -H "Host: localhost" -f http://localhost:8080/SYSTEM/success.tcl
  ```

If Docker Hub’s web UI appears stale after pushes, prefer registry-truth checks such as
`docker buildx imagetools inspect` or `docker manifest inspect`.


---

## License

This project is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL can be obtained from
https://mozilla.org/MPL/2.0/.

Copyright © 2025 Gustaf Neumann
