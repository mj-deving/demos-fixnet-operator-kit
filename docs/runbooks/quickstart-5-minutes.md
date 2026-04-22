# 5-Minute Quickstart

This is the shortest sane path for getting one fresh VPS onto DEMOS fixnet.

## 1. Open the required ports

Allow inbound:

- `22/tcp`
- `53550/tcp`
- `53551/tcp`
- `53551/udp`

## 2. SSH in as `root`

```bash
ssh root@<host>
```

## 3. Run the setup wrapper

From your admin machine:

```bash
./scripts/setup_fixnet_vps.sh \
  --ssh-target root@<host> \
  --ssh-identity-file ~/.ssh/<admin-key> \
  --public-url http://<public-ip-or-dns>:53550 \
  --fresh-host
```

If you prefer not to type flags every time:

```bash
cp examples/setup.config.env.example my-host.env
# edit my-host.env
./scripts/setup_fixnet_vps.sh --config my-host.env
```

If you are restoring an existing mnemonic already present on the host:

```bash
./scripts/setup_fixnet_vps.sh \
  --ssh-target root@<host> \
  --ssh-identity-file ~/.ssh/<admin-key> \
  --public-url http://<public-ip-or-dns>:53550 \
  --reuse-host \
  --identity-file /home/demos/.secrets/demos-mnemonic
```

## 4. If you want the manual path

```bash
ssh root@<host> 'bash -s -- --public-url http://<public-ip-or-dns>:53550 --fresh-host' < scripts/bootstrap_fixnet_host.sh
```

## 5. Verify `/info`

```bash
curl http://<public-ip-or-dns>:53550/info
ssh root@<host> 'systemctl status demos-node.service --no-pager'
```

## 6. Run a short burn-in

```bash
./scripts/monitor_fixnet_burnin.sh \
  --url http://<public-ip-or-dns>:53550/info \
  --ssh-target root@<public-ip-or-dns> \
  --ssh-identity-file ~/.ssh/<admin-key> \
  --samples 6 \
  --interval 30
```

## 7. Optional: enable full monitoring

If you want host-level metrics too:

```bash
./scripts/setup_fixnet_vps.sh \
  --ssh-target root@<host> \
  --ssh-identity-file ~/.ssh/<admin-key> \
  --public-url http://<public-ip-or-dns>:53550 \
  --fresh-host \
  --monitoring-profile full \
  --grafana-admin-password <strong-password>
```

Use SSH tunneling for Grafana and Prometheus by default instead of opening them publicly.

## 8. Keep one rule in mind

One host, one node, one mnemonic.

Do not reuse the same mnemonic across multiple hosts.
