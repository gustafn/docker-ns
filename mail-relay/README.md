# `docker-mail-relay`

A lightweight **Alpine-based Postfix SMTP relay** for containerized OpenACS/NaviServer environments.

This image is used in the `gustafn/openacs` Docker stack to provide a secure, relay-only outgoing mail server for OpenACS installations. It is optimized for simplicity, portability, and maintainability across dockerized deployments.

[![Docker Pulls](https://img.shields.io/docker/pulls/gustafn/mail-relay.svg)](https://hub.docker.com/r/gustafn/mail-relay)
[![Image Size](https://img.shields.io/docker/image-size/gustafn/mail-relay/latest)](https://hub.docker.com/r/gustafn/mail-relay)
[![License: MPL-2.0](https://img.shields.io/badge/License-MPL--2.0-blue.svg)](https://mozilla.org/MPL/2.0/)

---

## Features

* Minimal Postfix setup focused on **outgoing SMTP only**
  (`mydestination` empty; no local mailboxes)
* Relaying restricted to **trusted Docker subnets** (`mynetworks`)
* **STARTTLS** support for inbound SMTP from OpenACS (`nssmtpd`)
* Outbound mail delivered to real MX hosts using DNS
* Configuration generated from a template at container start
* Supports **bind-mounted custom `main.cf`** for advanced setups
* Small Alpine footprint

---

## Image contents

The following files are included in the image:

### **`/docker-entrypoint.sh`**

* Sets sane defaults for postfix-related environment variables
* Renders `/etc/postfix/main.cf` from a template using `envsubst`
* Skips rendering if `/etc/postfix/main.cf` is already present (bind-mount override)
* Runs `postfix check`
* Starts Postfix in the foreground

### **`/etc/postfix/main.cf.template`**

Template defining:

* relay-only behavior
* TLS configuration for inbound STARTTLS
* opportunistic TLS for outbound SMTP
* trusted networks (`mynetworks`)
* logging configuration

You can inspect these in a running container:

```sh
docker run --rm gustafn/mail-relay:latest cat /docker-entrypoint.sh
docker run --rm gustafn/mail-relay:latest cat /etc/postfix/main.cf.template
```

---

## Configuration via environment variables

| Variable                | Description                         | Default                                             |
| ----------------------- | ----------------------------------- | --------------------------------------------------- |
| `POSTFIX_TLS_CERT_FILE` | TLS certificate for inbound SMTP    | `/var/www/openacs.org/etc/openacs.org.pem`          |
| `POSTFIX_TLS_KEY_FILE`  | TLS key (defaults to same as cert)  | `${POSTFIX_TLS_CERT_FILE}`                          |
| `POSTFIX_MYORIGIN`      | Domain appended to bare local parts | `openacs.org`                                       |
| `POSTFIX_MYNETWORKS`    | List of trusted subnets             | `127.0.0.0/8 [::1]/128 172.16.0.0/12 172.27.0.0/16` |
| `TZ`                    | Time zone                           | `UTC` or system default                             |

If you bind-mount `/etc/postfix/main.cf`, none of these variables are used.

---

## Volumes

Typical mounts for OpenACS stacks:

```yaml
volumes:
  - /var/www/openacs.org:/var/www/openacs.org     # certificates, etc.
  - ${logdir}/postfix:/var/log                    # Postfix logs
```

To override the generated configuration:

```yaml
# Your custom Postfix config:
- /var/www/openacs.org/etc/postfix-main.cf:/etc/postfix/main.cf:ro
```

---

## Ports

The relay exposes SMTP **internally** only:

```yaml
expose:
  - "25"
```

The `openacs-org` container delivers mail to `mail-relay:25`.

No ports are published on the host by default.

---

## Example (docker-compose)

```yaml
services:

  mail-relay:
    image: gustafn/mail-relay:latest
    container_name: mail-relay
    hostname: smtpd.${hostname}
    restart: unless-stopped

    expose:
      - "25"

    environment:
      - TZ=Europe/Vienna
      - POSTFIX_TLS_CERT_FILE=${certificate}

    volumes:
      - /var/www/openacs.org:/var/www/openacs.org
      - ${logdir}/postfix:/var/log
```

Used together with:

```yaml
openacs-org:
  environment:
    oacs_smtpdhost: mail-relay
    oacs_smtpdport: 25
```

---

## Inspecting the container

See the generated configuration:

```sh
docker run --rm gustafn/mail-relay:latest postconf -n
```

See logs (if mapped):

```sh
docker logs mail-relay
```

---

## License

This project is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL can be obtained from
https://mozilla.org/MPL/2.0/.

Copyright © 2025 Gustaf Neumann
