# Dirty Host Harness

Use this harness when you want to exercise the real preflight script against disposable dirty-host scenarios instead of only checking evaluator fixtures.

## What it covers

Current scenarios:

- fresh candidate
- stale runtime
- legacy DEMOS install
- broken package manager

The harness builds a temporary fake host environment, stubs only the system probes that matter for classification, and runs the real `preflight_fixnet_host.sh` entrypoint.

## Run it

```bash
python3 scripts/run_dirty_host_integration.py
```

This is intended as a regression harness for the host-state detection path.

## Scope

It does not try to run a full VPS bootstrap.

It does:

- run the real preflight script
- validate exit code behavior
- validate classification and recommended strategy
- exercise repo residue and legacy-branch detection using temporary git repos
