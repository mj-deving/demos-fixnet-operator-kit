# Monitoring

The upstream DEMOS monitoring stack consists of:

- Prometheus
- Grafana
- optional `node-exporter` for the full profile

## Profiles

### Basic

Starts Prometheus and Grafana.

### Full

Starts Prometheus, Grafana, and `node-exporter` for host-level metrics.

In this template, full monitoring is enabled by:

```bash
--monitoring-profile full
```

The bootstrap script translates that into:

```bash
COMPOSE_PROFILES=full
```

so the upstream `docker compose` invocation in `./run` starts the optional `node-exporter` service too.

## Bootstrap options

```bash
--fresh-host | --reuse-host
--monitoring-profile basic|full
--metrics-port 9090
--prometheus-port 9091
--grafana-port 3000
--node-exporter-port 9100
--grafana-admin-user admin
--grafana-admin-password <password>
--grafana-root-url http://localhost:3000
```

The script writes:

- node `.env` with `METRICS_ENABLED=true`
- `monitoring/.env` with Grafana and Prometheus settings

The recommended wrapper is:

```bash
./scripts/setup_fixnet_vps.sh
```

It can also load a shell-style config file:

```bash
./scripts/setup_fixnet_vps.sh --config my-host.env
```

## Safe access

Default recommendation:

- keep Grafana and Prometheus private
- access them through SSH tunnels

Example:

```bash
ssh -L 3000:127.0.0.1:3000 -L 9091:127.0.0.1:9091 root@<host>
```

Then open:

- `http://127.0.0.1:3000`
- `http://127.0.0.1:9091`

## Public exposure

Only expose Grafana publicly if you first:

1. change the default password
2. restrict firewall access to trusted admin IPs
3. preferably put TLS or a reverse proxy in front of it

You do not need to expose `node-exporter` publicly. Prometheus scrapes it internally.
