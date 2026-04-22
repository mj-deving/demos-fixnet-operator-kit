# DEMOS Fixnet Template

Public, provider-neutral companion repo for bringing a fresh Linux host onto the DEMOS fixnet using the upstream [`kynesyslabs/node`](https://github.com/kynesyslabs/node) repository.

This repo is intentionally small. It does not contain any tenant inventory, provider API automation, live IP addresses, or mnemonic material. It only contains the reusable operator layer:

- a host bootstrap script
- a short burn-in monitor
- generalized runbooks for VPS and local-host usage
- safe examples for `.env` and `demos_peerlist.json`

## What This Repo Does

It helps you:

1. prepare one host per node
2. clone the upstream DEMOS node
3. restore an existing mnemonic or generate a fresh one
4. configure fixnet mode
5. install a systemd service
6. verify `/info`
7. run a short burn-in check

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

Run the bootstrap script on a fresh Ubuntu host as `root`:

```bash
ssh root@<host> 'bash -s -- --public-url http://<public-ip-or-dns>:53550' < scripts/bootstrap_fixnet_host.sh
```

If you already have a mnemonic on the host:

```bash
ssh root@<host> 'bash -s -- \
  --public-url http://<public-ip-or-dns>:53550 \
  --identity-file /home/demos/.secrets/demos-mnemonic' < scripts/bootstrap_fixnet_host.sh
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
- [docs/references/mnemonic-handling.md](docs/references/mnemonic-handling.md)
- [docs/references/public-sharing-boundary.md](docs/references/public-sharing-boundary.md)

## Safe Defaults

- one host per node
- one mnemonic per node
- SSH key auth only
- keep mnemonics outside git
- allow `20-30` seconds after restart before treating `/info` as unhealthy

## License

MIT for the operator-layer material in this repository. The upstream DEMOS node code remains under its own license in the upstream repository.
