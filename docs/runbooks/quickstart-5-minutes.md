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

## 3. Run the bootstrap

From your admin machine:

```bash
ssh root@<host> 'bash -s -- --public-url http://<public-ip-or-dns>:53550' < scripts/bootstrap_fixnet_host.sh
```

If you are restoring an existing mnemonic already present on the host:

```bash
ssh root@<host> 'bash -s -- \
  --public-url http://<public-ip-or-dns>:53550 \
  --identity-file /home/demos/.secrets/demos-mnemonic' < scripts/bootstrap_fixnet_host.sh
```

## 4. Verify `/info`

```bash
curl http://<public-ip-or-dns>:53550/info
ssh root@<host> 'systemctl status demos-node.service --no-pager'
```

## 5. Run a short burn-in

```bash
./scripts/monitor_fixnet_burnin.sh \
  --url http://<public-ip-or-dns>:53550/info \
  --ssh-target root@<public-ip-or-dns> \
  --ssh-identity-file ~/.ssh/<admin-key> \
  --samples 6 \
  --interval 30
```

## 6. Keep one rule in mind

One host, one node, one mnemonic.

Do not reuse the same mnemonic across multiple hosts.
