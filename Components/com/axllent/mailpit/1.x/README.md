# Mailpit

[Mailpit](https://mailpit.axllent.org/) as a Docker-based scenario component. It captures
outgoing mail (SMTP) and provides a web UI / API to inspect it.

**By default both SMTP and the web UI require a password.** SMTP and the UI/API
authenticate against the *same* auth file (see below), so one set of credentials
covers both.

## Ports

| Port | Purpose        | Container |
|------|----------------|-----------|
| `SCENARIO_RESOURCE_WEBUIPORT` (default `8025`) | Web UI / API | `8025` |
| `SCENARIO_RESOURCE_SMTPPORT`  (default `1025`) | SMTP         | `1025` |

## Authentication file (required)

Before the component can be started, a shared auth file must exist. It is mounted
read-only into the container and used for **both** `MP_SMTP_AUTH_FILE` and
`MP_UI_AUTH_FILE`.

- **File name:** `auth`
- **Location (relative to `SCENARIO_SRC_SECRETSDIR`):** `mailpit/auth`
- **Full path with default secrets dir:** `/var/dev/MIMS-Scenarios/_secrets/mailpit/auth`

The path is configurable via `SCENARIO_MAILPIT_AUTHFILE` (default `mailpit/auth`).

### Format

One `user:bcrypt-hash` entry per line. Multiple lines = multiple users. Create an
entry with `htpasswd`:

```bash
htpasswd -bnBC 10 admin 'YOUR_PASSWORD' >> /var/dev/MIMS-Scenarios/_secrets/mailpit/auth
```

The same credentials then apply to the SMTP login **and** the web UI / API.

`up`, `start` and `test` abort with an error if the file is missing or unreadable
(see `checkAuthFile` in [`scenario.sh`](scenario.sh)).

## Configuration

Defaults live in [`defaults.scenario.yaml`](defaults.scenario.yaml):

| Variable | Default | Description |
|----------|---------|-------------|
| `SCENARIO_MAILPIT_MAXMESSAGES` | `5000` | Max number of messages kept in the database |
| `SCENARIO_MAILPIT_AUTHFILE` | `mailpit/auth` | Shared SMTP + UI auth file, relative to the secrets dir |
| `SCENARIO_MAILPIT_SMTPAUTHALLOWINSECURE` | `1` | Allow SMTP auth over the plaintext port `1025` (no TLS) |

> **Note:** `SMTPAUTHALLOWINSECURE=1` is required as long as SMTP is used over the
> unencrypted port `1025` — credentials travel in clear text. Fine for internal /
> tunnelled use; if Mailpit is exposed publicly, run SMTP over TLS instead.

Mail data is persisted in the `data_storage` volume (`SCENARIO_DATA_VOLUME_1`,
external by default) at `/data/mailpit.db`.

## Commands

```bash
scenario.deploy <scenario> up       # create volume + start
scenario.deploy <scenario> start
scenario.deploy <scenario> stop
scenario.deploy <scenario> down
scenario.deploy <scenario> test     # check container is running
scenario.deploy <scenario> logs
scenario.deploy <scenario> backup   # backup the data volume
scenario.deploy <scenario> restore  # restore from a timestamped backup
scenario.deploy <scenario> update   # pull the latest image
```

## Optional: Traefik

Set `SCENARIO_TRAEFIK_ENABLE=true` to route the web UI through Traefik via
[`docker-compose.traefik.yml`](docker-compose.traefik.yml). Configure the host with
`SCENARIO_TRAEFIK_MAILPIT_URL` and the proxy network with
`SCENARIO_TRAEFIK_NETWORK_NAME`.
