# IoT backend with Docker Compose

A small IoT backend stack with InfluxDB 2, Grafana, Mosquitto MQTT, Telegraf and Nginx. Image versions are pinned directly in `docker-compose.yml`.

## Requirements

- Docker Engine and the Docker Compose plugin
- DNS records pointing to this host when using non-local hostnames
- A TLS certificate covering the hostnames used in the current environment

## Hostnames

| Service | Deployment example | Local development | Docker upstream |
| --- | --- | --- | --- |
| Grafana | `https://grafana.example.com` | `https://grafana.localhost` | `grafana:3000` |
| InfluxDB UI and API | `https://influx.example.com` | `https://influxdb.localhost` | `influxdb:8086` |

Replace the deployment example names with your own domains. All listed hosts accept HTTP and redirect to HTTPS on the same host.

For local development, the hostnames must resolve to loopback. If your system does not resolve them automatically, add this entry to your hosts file:

```text
127.0.0.1 grafana.localhost influxdb.localhost
```

MQTT is available directly on TCP port `1883` and requires authentication.

## Setup

1. Copy `env.example` to `.env` and set strong passwords and a long random InfluxDB token. Do not commit `.env`.
2. Create the Mosquitto password file using the same MQTT username and password:

   ```sh
   docker compose run --rm --entrypoint mosquitto_passwd mosquitto -c /mosquitto/config/passwd iot
   ```

   The command prompts for the MQTT password. It must match `MQTT_PASSWORD` in `.env`.
3. Put the certificate and private key in `nginx/certs/fullchain.pem` and `nginx/certs/privkey.pem`.

   For development, run `make certs` to generate a self-signed certificate using `nginx/openssl.cnf`. It covers all four configured hostnames; configure your development client to trust this certificate explicitly. Running `make certs` replaces the existing certificate and key.
4. Set `GF_SERVER_ROOT_URL` in `docker-compose.yml` to the Grafana URL for your environment from the table above, with a trailing slash. For local development, use `https://grafana.localhost/`. Recreate the Grafana container after changing this value.

   If using different DNS names, update `server_name` values in `nginx/conf.d/101-grafana.conf`, `nginx/conf.d/102-influxdb.conf`, and `nginx/conf.d/100-http-redirect.conf`. Ensure your certificate covers the new names; if generating it with `make certs`, update the Subject Alternative Names in `nginx/openssl.cnf` first.
5. Start the stack:

   ```sh
   docker compose up -d
   ```

## Nginx maintenance

Nginx supports Grafana Live WebSockets and streams InfluxDB query responses. InfluxDB requests accept bodies up to 50 MiB with a 300-second upstream timeout.

After changing the Nginx configuration or renewing certificates, validate and reload the running service:

```sh
docker compose exec nginx nginx -t && docker compose exec nginx nginx -s reload
```

## MQTT payloads

Publish JSON messages to a topic under `sensors/`, for example `sensors/room1`:

```json
{"device_id":"sensor-01","temperature":21.7,"humidity":48.2}
```

Telegraf parses the JSON fields and writes them to the configured InfluxDB bucket. `device_id` and `sensor`, when present, are stored as tags.

InfluxDB bootstrap variables in `.env` are applied only when its data volume is first initialized. Back up the named Docker volumes before recreating or migrating the stack.
