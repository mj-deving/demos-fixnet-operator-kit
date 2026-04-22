# DEMOS Fixnet Template

Public, provider-neutral companion repo for bringing a fresh Linux host onto the DEMOS fixnet using the upstream [`kynesyslabs/node`](https://github.com/kynesyslabs/node) repository.

This repo is intentionally small. It does not contain any tenant inventory, provider API automation, live IP addresses, or mnemonic material. It only contains the reusable operator layer:

- a one-command VPS setup wrapper
- a remote preflight checker
- a host bootstrap script
- a post-bootstrap verifier
- a short burn-in monitor
- upstream-aligned monitoring support with optional full profile
- generalized runbooks for VPS and local-host usage
- safe examples for `.env` and `demos_peerlist.json`

## What This Repo Does

It helps you:

1. prepare one host per node
2. preflight-check the target host
3. clone the upstream DEMOS node
4. restore an existing mnemonic or generate a fresh one
5. configure fixnet mode
6. install a systemd service
7. verify `/info`
8. run a short burn-in check

## What This Repo Does Not Do

- manage any specific VPS provider
- create or store mnemonics
- publish live fleet data
- replace the upstream node repository

## Upstream

- Upstream repo: `https://github.com/kynesyslabs/node`
- Recommended branch for fixnet: `stabilisation`
- Upstream docs:
  - `INSTALL.md`
  - `documentation/join-fixnet.md`
  - `documentation/multipleinstances.md`

## Quick Start

Shortest path:

- [docs/runbooks/quickstart-5-minutes.md](docs/runbooks/quickstart-5-minutes.md)

### VPS host

Preferred path from your admin machine:

```bash
./scripts/setup_fixnet_vps.sh \
  --ssh-target root@<host> \
  --ssh-identity-file ~/.ssh/<admin-key> \
  --public-url http://<public-ip-or-dns>:53550 \
  --fresh-host
```

Same flow from a reusable config file:

```bash
./scripts/setup_fixnet_vps.sh --config examples/setup.config.env.example
```

Identity modes:

- `auto`: reuse `--identity-file` if it exists, otherwise generate
- `existing`: require an existing identity file
- `generate`: force a new identity and refuse to overwrite an existing file

Direct bootstrap is still available if you want to run the steps manually:

```bash
ssh root@<host> 'bash -s -- --public-url http://<public-ip-or-dns>:53550 --fresh-host' < scripts/bootstrap_fixnet_host.sh
```

If you already have a mnemonic on the host:

```bash
ssh root@<host> 'bash -s -- \
  --public-url http://<public-ip-or-dns>:53550 \
  --reuse-host \
  --identity-mode existing \
  --identity-file /home/demos/.secrets/demos-mnemonic' < scripts/bootstrap_fixnet_host.sh
```

If you want the upstream full monitoring profile with `node-exporter`:

```bash
ssh root@<host> 'bash -s -- \
  --public-url http://<public-ip-or-dns>:53550 \
  --fresh-host \
  --monitoring-profile full \
  --grafana-admin-password <strong-password>' < scripts/bootstrap_fixnet_host.sh
```

### Short burn-in

```bash
./scripts/monitor_fixnet_burnin.sh \
  --url http://<public-ip-or-dns>:53550/info \
  --ssh-target root@<public-ip-or-dns> \
  --ssh-identity-file ~/.ssh/<admin-key>
```

## Documents

- [docs/runbooks/vps-bootstrap.md](docs/runbooks/vps-bootstrap.md)
- [docs/runbooks/local-host-bootstrap.md](docs/runbooks/local-host-bootstrap.md)
- [docs/runbooks/quickstart-5-minutes.md](docs/runbooks/quickstart-5-minutes.md)
- [docs/runbooks/monitoring.md](docs/runbooks/monitoring.md)
- [docs/runbooks/dirty-host-harness.md](docs/runbooks/dirty-host-harness.md)
- [docs/runbooks/restore-archived-install.md](docs/runbooks/restore-archived-install.md)
- [docs/references/mnemonic-handling.md](docs/references/mnemonic-handling.md)
- [docs/references/public-sharing-boundary.md](docs/references/public-sharing-boundary.md)
- [examples/setup.config.env.example](examples/setup.config.env.example)

## Safe Defaults

- one host per node
- one mnemonic per node
- use `setup_fixnet_vps.sh` unless you intentionally want manual control
- `--fresh-host` fails fast on residue, `--reuse-host` intentionally replaces an existing install
- `--reuse-host` archives replaceable state under `/var/backups/demos-fixnet`
- use `restore_archived_install.sh` if a reuse-host replacement goes wrong and you need the archived config path back
- use `python3 scripts/run_dirty_host_integration.py` to regression-check dirty-host classification behavior
- SSH key auth only
- keep mnemonics outside git
- allow `20-30` seconds after restart before treating `/info` as unhealthy

## License

MIT for the operator-layer material in this repository. The upstream DEMOS node code remains under its own license in the upstream repository.
