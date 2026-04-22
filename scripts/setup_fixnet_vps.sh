#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

CONFIG_FILE=""
SSH_TARGET=""
SSH_IDENTITY_FILE=""
PUBLIC_URL=""
HOST_MODE=""
IDENTITY_FILE=""
MONITORING_PROFILE="basic"
UPSTREAM_REPO=""
BRANCH=""
METRICS_PORT=""
PROMETHEUS_PORT=""
GRAFANA_PORT=""
NODE_EXPORTER_PORT=""
GRAFANA_ADMIN_USER=""
GRAFANA_ADMIN_PASSWORD=""
GRAFANA_ROOT_URL=""
ANCHOR_PUBKEY=""
ANCHOR_URL=""
SKIP_PRECHECK=false
SKIP_VERIFY=false
PRINT_PREFLIGHT_JSON=false
PREFLIGHT_REPORT_FILE=""

usage() {
	cat <<'EOF'
One-command DEMOS fixnet VPS setup wrapper.

Run from your admin machine. This script performs:
  1. remote preflight
  2. remote bootstrap
  3. post-bootstrap verification

Required:
  --ssh-target root@<host>
  --public-url http://<public-ip-or-dns>:53550
  --fresh-host | --reuse-host

Optional:
  --config ./my-host.env
  --ssh-identity-file ~/.ssh/<admin-key>
  --identity-file /home/demos/.secrets/demos-mnemonic
  --monitoring-profile basic|full
  --upstream-repo https://github.com/kynesyslabs/node.git
  --branch stabilisation
  --metrics-port 9090
  --prometheus-port 9091
  --grafana-port 3000
  --node-exporter-port 9100
  --grafana-admin-user admin
  --grafana-admin-password <password>
  --grafana-root-url http://localhost:3000
  --anchor-pubkey 0x...
  --anchor-url http://node3.demos.sh:60001
  --print-preflight-json
  --preflight-report-file ./preflight.json
  --skip-precheck
  --skip-verify
EOF
}

load_config_file() {
	local path="$1"
	if [[ ! -f "${path}" ]]; then
		echo "Config file not found: ${path}" >&2
		exit 1
	fi
	set -a
	# shellcheck disable=SC1090
	source "${path}"
	set +a
}

for arg_index in "$@"; do
	:
done

args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
	if [[ "${args[i]}" == "--config" ]]; then
		if (( i + 1 >= ${#args[@]} )); then
			echo "--config requires a file path" >&2
			exit 1
		fi
		CONFIG_FILE="${args[i+1]}"
		load_config_file "${CONFIG_FILE}"
		break
	fi
done

SSH_TARGET="${SSH_TARGET:-}"
SSH_IDENTITY_FILE="${SSH_IDENTITY_FILE:-}"
PUBLIC_URL="${PUBLIC_URL:-}"
HOST_MODE="${HOST_MODE:-}"
IDENTITY_FILE="${IDENTITY_FILE:-}"
MONITORING_PROFILE="${MONITORING_PROFILE:-basic}"
UPSTREAM_REPO="${UPSTREAM_REPO:-}"
BRANCH="${BRANCH:-}"
METRICS_PORT="${METRICS_PORT:-}"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-}"
GRAFANA_PORT="${GRAFANA_PORT:-}"
NODE_EXPORTER_PORT="${NODE_EXPORTER_PORT:-}"
GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-}"
GRAFANA_ROOT_URL="${GRAFANA_ROOT_URL:-}"
ANCHOR_PUBKEY="${ANCHOR_PUBKEY:-}"
ANCHOR_URL="${ANCHOR_URL:-}"

while [[ $# -gt 0 ]]; do
	case "$1" in
	--config)
		CONFIG_FILE="${2:-}"
		shift 2
		;;
	--ssh-target)
		SSH_TARGET="${2:-}"
		shift 2
		;;
	--ssh-identity-file)
		SSH_IDENTITY_FILE="${2:-}"
		shift 2
		;;
	--public-url)
		PUBLIC_URL="${2:-}"
		shift 2
		;;
	--fresh-host)
		HOST_MODE="fresh"
		shift
		;;
	--reuse-host)
		HOST_MODE="reuse"
		shift
		;;
	--identity-file)
		IDENTITY_FILE="${2:-}"
		shift 2
		;;
	--monitoring-profile)
		MONITORING_PROFILE="${2:-}"
		shift 2
		;;
	--upstream-repo)
		UPSTREAM_REPO="${2:-}"
		shift 2
		;;
	--branch)
		BRANCH="${2:-}"
		shift 2
		;;
	--metrics-port)
		METRICS_PORT="${2:-}"
		shift 2
		;;
	--prometheus-port)
		PROMETHEUS_PORT="${2:-}"
		shift 2
		;;
	--grafana-port)
		GRAFANA_PORT="${2:-}"
		shift 2
		;;
	--node-exporter-port)
		NODE_EXPORTER_PORT="${2:-}"
		shift 2
		;;
	--grafana-admin-user)
		GRAFANA_ADMIN_USER="${2:-}"
		shift 2
		;;
	--grafana-admin-password)
		GRAFANA_ADMIN_PASSWORD="${2:-}"
		shift 2
		;;
	--grafana-root-url)
		GRAFANA_ROOT_URL="${2:-}"
		shift 2
		;;
	--anchor-pubkey)
		ANCHOR_PUBKEY="${2:-}"
		shift 2
		;;
	--anchor-url)
		ANCHOR_URL="${2:-}"
		shift 2
		;;
	--print-preflight-json)
		PRINT_PREFLIGHT_JSON=true
		shift
		;;
	--preflight-report-file)
		PREFLIGHT_REPORT_FILE="${2:-}"
		shift 2
		;;
	--skip-precheck)
		SKIP_PRECHECK=true
		shift
		;;
	--skip-verify)
		SKIP_VERIFY=true
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "Unknown argument: $1" >&2
		usage >&2
		exit 1
		;;
	esac
done

if [[ -z "${SSH_TARGET}" || -z "${PUBLIC_URL}" || -z "${HOST_MODE}" ]]; then
	echo "--ssh-target, --public-url, and one of --fresh-host/--reuse-host are required" >&2
	exit 1
fi

ssh_cmd=(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new)
if [[ -n "${SSH_IDENTITY_FILE}" ]]; then
	ssh_cmd+=(-i "${SSH_IDENTITY_FILE}")
fi

remote_run() {
	local script_path="$1"
	shift
	local quoted=""
	local arg
	for arg in "$@"; do
		quoted+=" $(printf '%q' "${arg}")"
	done
	"${ssh_cmd[@]}" "${SSH_TARGET}" "bash -s --${quoted}" < "${script_path}"
}

run_remote_preflight() {
	local tmp=""

	if [[ "${PRINT_PREFLIGHT_JSON}" == "true" || -n "${PREFLIGHT_REPORT_FILE}" ]]; then
		tmp="$(mktemp)"
		remote_run "${SCRIPT_DIR}/preflight_fixnet_host.sh" "${shared_args[@]}" --json >"${tmp}"
		if [[ "${PRINT_PREFLIGHT_JSON}" == "true" ]]; then
			cat "${tmp}"
		fi
		if [[ -n "${PREFLIGHT_REPORT_FILE}" ]]; then
			cp "${tmp}" "${PREFLIGHT_REPORT_FILE}"
			echo "==> Wrote preflight report to ${PREFLIGHT_REPORT_FILE}"
		fi
		if [[ "${PRINT_PREFLIGHT_JSON}" != "true" ]]; then
			python3 - "${tmp}" <<'PY'
import json
import sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
summary = data["summary"]
print(
    f"==> Preflight classification: {summary['classification']} "
    f"(strategy: {summary['recommended_strategy']}, failures={summary['failures']}, warnings={summary['warnings']})"
)
PY
		fi
		rm -f "${tmp}"
	else
		remote_run "${SCRIPT_DIR}/preflight_fixnet_host.sh" "${shared_args[@]}"
	fi
}

shared_args=(--public-url "${PUBLIC_URL}")

if [[ "${HOST_MODE}" == "fresh" ]]; then
	shared_args+=(--fresh-host)
else
	shared_args+=(--reuse-host)
fi

if [[ -n "${IDENTITY_FILE}" ]]; then
	shared_args+=(--identity-file "${IDENTITY_FILE}")
fi
if [[ -n "${UPSTREAM_REPO}" ]]; then
	shared_args+=(--upstream-repo "${UPSTREAM_REPO}")
fi
if [[ -n "${BRANCH}" ]]; then
	shared_args+=(--branch "${BRANCH}")
fi
if [[ -n "${METRICS_PORT}" ]]; then
	shared_args+=(--metrics-port "${METRICS_PORT}")
fi
if [[ -n "${PROMETHEUS_PORT}" ]]; then
	shared_args+=(--prometheus-port "${PROMETHEUS_PORT}")
fi
if [[ -n "${GRAFANA_PORT}" ]]; then
	shared_args+=(--grafana-port "${GRAFANA_PORT}")
fi
if [[ -n "${NODE_EXPORTER_PORT}" ]]; then
	shared_args+=(--node-exporter-port "${NODE_EXPORTER_PORT}")
fi
if [[ -n "${GRAFANA_ADMIN_USER}" ]]; then
	shared_args+=(--grafana-admin-user "${GRAFANA_ADMIN_USER}")
fi
if [[ -n "${GRAFANA_ADMIN_PASSWORD}" ]]; then
	shared_args+=(--grafana-admin-password "${GRAFANA_ADMIN_PASSWORD}")
fi
if [[ -n "${GRAFANA_ROOT_URL}" ]]; then
	shared_args+=(--grafana-root-url "${GRAFANA_ROOT_URL}")
fi
if [[ -n "${ANCHOR_PUBKEY}" ]]; then
	shared_args+=(--anchor-pubkey "${ANCHOR_PUBKEY}")
fi
if [[ -n "${ANCHOR_URL}" ]]; then
	shared_args+=(--anchor-url "${ANCHOR_URL}")
fi
if [[ "${MONITORING_PROFILE}" != "basic" ]]; then
	shared_args+=(--monitoring-profile "${MONITORING_PROFILE}")
fi

if [[ "${SKIP_PRECHECK}" != "true" ]]; then
	echo "==> Running remote preflight"
	run_remote_preflight
fi

echo "==> Running remote bootstrap"
remote_run "${SCRIPT_DIR}/bootstrap_fixnet_host.sh" "${shared_args[@]}"

if [[ "${SKIP_VERIFY}" != "true" ]]; then
	echo "==> Running post-bootstrap verification"
	verify_args=(--url "${PUBLIC_URL}/info" --ssh-target "${SSH_TARGET}" --monitoring-profile "${MONITORING_PROFILE}")
	if [[ -n "${SSH_IDENTITY_FILE}" ]]; then
		verify_args+=(--ssh-identity-file "${SSH_IDENTITY_FILE}")
	fi
	"${SCRIPT_DIR}/verify_fixnet_host.sh" "${verify_args[@]}"
fi

echo "==> Setup flow completed"
