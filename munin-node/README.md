
# `docker-munin-node-openacs`

[![Docker Pulls](https://img.shields.io/docker/pulls/gustafn/munin-node-openacs.svg)](https://hub.docker.com/r/gustafn/munin-node-openacs)
[![Image Size](https://img.shields.io/docker/image-size/gustafn/munin-node-openacs/latest)](https://hub.docker.com/r/gustafn/munin-node-openacs)
[![License: MPL-2.0](https://img.shields.io/badge/License-MPL--2.0-blue.svg)](https://mozilla.org/MPL/2.0/)

**Alpine-based Munin Node container with built-in NaviServer/OpenACS monitoring plugins.**

This image provides a lightweight and fully preconfigured `munin-node` suitable for monitoring NaviServer/OpenACS deployments, including full support for the `munin-plugins-ns` plugin suite.

It is intended to be paired with a standard Munin master installation.

---

## Features

* **Alpine-based, minimal footprint**
* Runs `munin-node` in foreground for clean container lifecycle
* Bundles **NaviServer/OpenACS Munin plugins** from
  [https://github.com/gustafn/munin-plugins-ns](https://github.com/gustafn/munin-plugins-ns)
  (no manual installation required)
* Automatic symlinking of plugins via `/etc/munin/plugins/`
* Supports Docker-network monitoring setups
* Simple volume mapping for Munin plugin state and logs
* Configuration via environment variables and optional custom config files

---

## Image contents

This repository includes:

### `/docker-entrypoint.sh`

* Installs Munin plugins
* Generates plugin symlinks dynamically
* Ensures correct permissions
* Starts `munin-node --foreground`

### `/etc/munin/munin-node.conf.template`

* Base template for `munin-node.conf`
* Allows injection of hostname, allow rules, and ports via environment variables

### Included plugin suite:

From `munin-plugins-ns`:

* `naviserver_*` metrics
* nsstats integration
* timers, connections, threadpool, mem, IO, file descriptors, etc.

Plugins are installed under:

```
/usr/local/munin/plugins/
```

and symlinked into:

```
/etc/munin/plugins/
```

---

## Configuration

### Environment variables

| Variable         | Description                                                  | Default            |
| ---------------- | ------------------------------------------------------------ | ------------------ |
| `TZ`             | Time zone                                                    | `UTC`              |
| `MUNIN_ALLOW`    | Comma-separated IPv4/IPv6 networks allowed to query the node | `127.0.0.1`        |
| `MUNIN_HOSTNAME` | Hostname reported to Munin master                            | container hostname |
| `MUNIN_PORT`     | Listening port                                               | `4949`             |

### Overriding the generated configuration

Mount your own config to bypass the template:

```yaml
- ./munin-node.conf:/etc/munin/munin-node.conf:ro
```

---

## Volumes

Typical use:

```yaml
volumes:
  - ${logdir}/munin-node:/var/log
```

State files (e.g., plugin caches) live inside the container; you can persist them if desired.

---

## Ports

Munin Node always listens on:

```
4949/tcp
```

Expose it to your Docker network:

```yaml
expose:
  - "4949"
```

If you want to reach it from host or a remote Munin master:

```yaml
ports:
  - "4949:4949"
```

---

## Example docker-compose

```yaml
services:

  munin-node:
    image: gustafn/munin-node:latest
    container_name: munin-node
    hostname: munin-node.${hostname}
    restart: unless-stopped

    expose:
      - "4949"

    environment:
      - TZ=Europe/Vienna
      - MUNIN_ALLOW=172.16.0.0/12

    volumes:
      - /var/www/openacs.org:/var/www/openacs.org:ro
      - ${logdir}/munin-node:/var/log
```

A Munin master can then add:

```
[openacs.org]
    address munin-node
    use_node_name yes
```

---

## Inspecting the container

List plugins:

```sh
docker run --rm gustafn/munin-node:latest ls /usr/local/munin/plugins
```

Show active plugin links:

```sh
docker exec -it munin-node ls -l /etc/munin/plugins
```

Test Munin connection:

```sh
nc munin-node 4949
```

---

## License

This project is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL can be obtained from
https://mozilla.org/MPL/2.0/.

Copyright © 2025 Gustaf Neumann

