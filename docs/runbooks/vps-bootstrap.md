# VPS Bootstrap

Use this path for a fresh public VPS where you want exactly one DEMOS node on the host.

## Network Requirements

Allow inbound:

- `22/tcp`
- `53550/tcp`
- `53551/tcp`
- `53551/udp`

## Bootstrap

Recommended path from your admin machine:

```bash
./scripts/setup_fixnet_vps.sh \
  --ssh-target root@<host> \
  --ssh-identity-file ~/.ssh/<admin-key> \
  --public-url http://<public-ip-or-dns>:53550 \
  --fresh-host
```

Config-file driven path:

```bash
cp examples/setup.config.env.example my-host.env
# edit my-host.env
./scripts/setup_fixnet_vps.sh --config my-host.env
```

This wrapper runs:

1. remote preflight
2. remote bootstrap
3. post-bootstrap verification

Optional machine-readable host classification:

```bash
./scripts/setup_fixnet_vps.sh --config my-host.env --print-preflight-json --skip-verify
```

Manual path, if you want to split the steps yourself:

```bash
ssh root@<host> 'bash -s -- --public-url http://<public-ip-or-dns>:53550 --fresh-host' < scripts/bootstrap_fixnet_host.sh
```

If you want to reuse an existing mnemonic that already lives on the host:

```bash
./scripts/setup_fixnet_vps.sh \
  --ssh-target root@<host> \
  --ssh-identity-file ~/.ssh/<admin-key> \
  --public-url http://<public-ip-or-dns>:53550 \
  --reuse-host \
  --identity-file /home/demos/.secrets/demos-mnemonic
```

## Verification

Post-bootstrap verifier:

```bash
./scripts/verify_fixnet_host.sh \
  --url http://<public-ip-or-dns>:53550/info \
  --ssh-target root@<public-ip-or-dns> \
  --ssh-identity-file ~/.ssh/<admin-key>
```

Manual checks:

```bash
curl http://<public-ip-or-dns>:53550/info
ssh root@<host> 'systemctl status demos-node.service --no-pager'
```

## Burn-in

```bash
./scripts/monitor_fixnet_burnin.sh \
  --url http://<public-ip-or-dns>:53550/info \
  --ssh-target root@<public-ip-or-dns> \
  --ssh-identity-file ~/.ssh/<admin-key> \
  --samples 12 \
  --interval 30
```

After `systemctl restart demos-node.service`, give the node roughly `20-30` seconds before expecting `/info` to return.

## Full monitoring

If you want upstream full-profile monitoring with `node-exporter`:

```bash
./scripts/setup_fixnet_vps.sh \
  --ssh-target root@<host> \
  --ssh-identity-file ~/.ssh/<admin-key> \
  --public-url http://<public-ip-or-dns>:53550 \
  --fresh-host \
  --monitoring-profile full \
  --grafana-admin-password <strong-password>
```

For safe access defaults, see [monitoring.md](monitoring.md).
