# `docker-munin-master`

[![Docker Pulls](https://img.shields.io/docker/pulls/gustafn/munin-master.svg)](https://hub.docker.com/r/gustafn/munin-master)
[![Image Size](https://img.shields.io/docker/image-size/gustafn/munin-master/latest)](https://hub.docker.com/r/gustafn/munin-master)
[![License: MPL-2.0](https://img.shields.io/badge/License-MPL--2.0-blue.svg)](https://mozilla.org/MPL/2.0/)

Docker image providing a **Munin master** tuned for Docker-based deployments and, in particular, for use with:

- [`gustafn/munin-node-openacs`](https://github.com/gustafn/docker-munin-node-openacs)
- [`gustafn/openacs`](https://hub.docker.com/repository/docker/gustafn/openacs)
- [`gustafn/mail-relay`](https://hub.docker.com/repository/docker/gustafn/mail-relay)

The container runs the Munin master daemon (`munin-cron` via `crond`) and writes:

- RRD databases under `/var/lib/munin`
- HTML pages and graphs under `/var/www/munin`
- Logs under `/var/log/munin`

These directories are meant to be bind-mounted to the host (e.g. into the OpenACS document tree).

The corresponding Docker Hub image is:

- **`gustafn/munin-master`**

---

## Features

- Based on **Alpine Linux**
- Automatically generates `/etc/munin/munin.conf` from a template at startup
- Runs `munin-cron` periodically via `crond` (default: every minute)
- Optional **UID/GID mapping** to a host user (`MUNIN_HOST_USER`) so that generated files are owned by the right account (e.g. `nsadmin`)
- Connectivity check to the Munin node before cron startup
- Sets up `fontconfig` cache so that graph rendering works reliably
- Minimal configuration via environment variables

---

## How It Works

On container start, the entrypoint script:

1. Reads environment variables and prints a short summary.
2. If you did not mount your own `munin.conf`, generates one from the template:
   ```sh
   envsubst < /etc/munin/munin.conf.template > /etc/munin/munin.conf
   ```

3. Ensures that the following directories exist and are writable by the `munin` user:

   * `$MUNIN_DB_DIR` (default `/var/lib/munin`)
   * `$MUNIN_HTML_DIR` (default `/var/www/munin`)
   * `$MUNIN_LOG_DIR` (default `/var/log/munin`)
   * `$MUNIN_RUN_DIR` (default `/var/run/munin`)
  
4. Optionally maps the **container munin user** to a **host user**:

   * If `MUNIN_HOST_USER` is set and `/host-etc/passwd` is mounted, it finds the UID/GID of that host user and updates the `munin` user inside the container accordingly.
   * It then `chown`s the Munin directories to that UID/GID.
5. Creates `/var/cache/fontconfig` and makes it writable by `munin` so fonts/graphs work.
6. Performs a simple TCP connectivity check to the node:

   * `MUNIN_NODE_ADDRESS:4949`
7. Installs a cron entry (into `/etc/crontabs/root`):

   ```cron
   */1 * * * * su -s /bin/sh munin -c /usr/bin/munin-cron
   ```
8. Starts `crond` in the foreground:

   ```sh
   exec crond -f -l 8 -L /var/log/cron.log
   ```

---

## Configuration

### Environment Variables

#### Core paths

| Variable         | Default                | Description                                         |
| ---------------- | ---------------------- | --------------------------------------------------- |
| `MUNIN_DB_DIR`   | `/var/lib/munin`       | RRD database directory                              |
| `MUNIN_HTML_DIR` | `/var/www/munin`       | HTML + PNG graph output directory                   |
| `MUNIN_LOG_DIR`  | `/var/log/munin`       | Munin master log directory                          |
| `MUNIN_RUN_DIR`  | `/var/run/munin`       | Runtime + lock directory (can be changed if needed) |
| `MUNIN_TPL_DIR`  | `/etc/munin/templates` | Template directory for `munin-html`                 |

These values are substituted into `munin.conf` via `envsubst`.

#### Node selection

| Variable             | Default       | Description                                       |
| -------------------- | ------------- | ------------------------------------------------- |
| `MUNIN_HOSTNAME`     | `openacs.org` | Logical node name inside Munin hierarchy          |
| `MUNIN_NODE_ADDRESS` | `munin-node`  | Hostname / service name of the Munin node to poll |

The generated `munin.conf` will typically contain something like:

```text
[openacs.org]
    address munin-node
    use_node_name yes
```

#### Owner mapping (optional)

| Variable          | Default   | Description                                                                                                             |
| ----------------- | --------- | ----------------------------------------------------------------------------------------------------------------------- |
| `MUNIN_HOST_USER` | *(unset)* | Host username to which the container’s `munin` user should be mapped (UID/GID). Requires `/host-etc/passwd` bind mount. |

Example: if you set `MUNIN_HOST_USER=nsadmin` and mount `/etc/passwd:/host-etc/passwd:ro`, the entrypoint will:

* find the UID/GID of `nsadmin` on the host,
* modify the `munin` user inside the container to use that UID/GID,
* `chown` `$MUNIN_DB_DIR`, `$MUNIN_HTML_DIR`, `$MUNIN_LOG_DIR` and `$MUNIN_RUN_DIR` to that UID/GID.

This is especially useful when you bind-mount `/var/www/openacs.org/www/munin-container` and want the files to be owned by the same user that owns the OpenACS tree.

#### Misc

| Variable | Default         | Description         |
| -------- | --------------- | ------------------- |
| `TZ`     | `Europe/Vienna` | Container time zone |

---

## Volumes

Typical bind mounts:

| Host path                                         | Container path        | Purpose                                     |
| ------------------------------------------------- | --------------------- | ------------------------------------------- |
| `/var/www/openacs.org/www/munin-container`        | `/var/www/munin`      | Munin HTML + PNG graphs (served by OpenACS) |
| `/var/www/openacs.org/log-container/munin-db`     | `/var/lib/munin`      | RRD databases (persistent)                  |
| `/var/www/openacs.org/log-container/munin-master` | `/var/log/munin`      | Munin logs                                  |
| `/etc/passwd`                                     | `/host-etc/passwd:ro` | Host user lookup for `MUNIN_HOST_USER`      |

You can adjust these to your own layout.

---

## Example: OpenACS + Munin

Here is a minimal example of how `gustafn/munin-master` can be used in a stack with `gustafn/munin-node-openacs` and `gustafn/openacs`:

```yaml
version: "3.8"

services:
  openacs-org:
    image: gustafn/openacs:latest
    container_name: openacs-org
    restart: unless-stopped
    networks:
      - oacs-net
    # ... (OpenACS configuration omitted here)

  munin-node:
    image: gustafn/munin-node-openacs:latest
    container_name: munin-node
    restart: unless-stopped
    depends_on:
      - openacs-org
    networks:
      - oacs-net
    environment:
      TZ: Europe/Vienna
      MUNIN_HOSTNAME: openacs.org
      MUNIN_ALLOW_CIDR: 172.30.0.0/16
      NS_SERVER_NAME: openacs.org
      NS_ADDRESS: openacs-org
      NS_PORT: 8888            # OpenACS loopback port
      NS_URL_PATH: /SYSTEM/munin.tcl?t=
    volumes:
      - /var/www/openacs.org/log-container/munin-node:/var/log/munin

  munin-master:
    image: gustafn/munin-master:latest
    container_name: munin-master
    restart: unless-stopped
    depends_on:
      - munin-node
    networks:
      - oacs-net
    environment:
      TZ: Europe/Vienna
      MUNIN_HOSTNAME: openacs.org
      MUNIN_NODE_ADDRESS: munin-node
      MUNIN_HOST_USER: nsadmin
      # Optionally override run dir:
      # MUNIN_RUN_DIR: /var/log/munin
    volumes:
      - /var/www/openacs.org/log-container/munin-db:/var/lib/munin
      - /var/www/openacs.org/log-container/munin-master:/var/log/munin
      - /var/www/openacs.org/www/munin-container:/var/www/munin
      - /etc/passwd:/host-etc/passwd:ro

networks:
  oacs-net:
    name: oacs-net
    driver: bridge
    ipam:
      config:
        - subnet: 172.30.0.0/16
```

With this setup:

* `munin-master` polls `munin-node` over the internal network (`oacs-net`).
* `munin-node` fetches metrics from `openacs-org` via its internal loopback port (8888).
* `munin-master` writes HTML and PNG graphs into `/var/www/openacs.org/www/munin-container`.
* OpenACS can then serve `/munin/` directly via HTTPS.

---

## Building the Image

To build the image locally:

```bash
git clone https://github.com/gustafn/docker-munin-master.git
cd docker-munin-master

# Build Alpine-based image
docker build -f Dockerfile.alpine -t gustafn/munin-master:local .
```

You can then reference `gustafn/munin-master:local` in your compose file for testing.

---

## Related Repositories

* `gustafn/docker-munin-node-openacs`
  Munin node with NaviServer/OpenACS plugins:
  [https://github.com/gustafn/docker-munin-node-openacs](https://github.com/gustafn/docker-munin-node-openacs)

* `gustafn/openacs`
  OpenACS/NaviServer Docker image:
  [https://hub.docker.com/repository/docker/gustafn/openacs](https://hub.docker.com/repository/docker/gustafn/openacs)

* `gustafn/mail-relay`
  Lightweight Postfix-based SMTP relay:
  [https://hub.docker.com/repository/docker/gustafn/mail-relay](https://hub.docker.com/repository/docker/gustafn/mail-relay)

---

## License

This project is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL can be obtained from
https://mozilla.org/MPL/2.0/.

Copyright © 2025 Gustaf Neumann
