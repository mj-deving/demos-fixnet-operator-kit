#!/usr/bin/env bash
set -euo pipefail

PUBLIC_URL=""
HOST_MODE=""
USER_NAME="demos"
REPO_DIR=""
IDENTITY_FILE=""
MONITORING_PROFILE="basic"
METRICS_PORT="9090"
PROMETHEUS_PORT="9091"
GRAFANA_PORT="3000"
NODE_EXPORTER_PORT="9100"
OUTPUT_JSON=false
EVENTS_FILE=""

usage() {
	cat <<'EOF'
Preflight checks for a DEMOS fixnet host.

Run on the target host as root before bootstrap.

Required:
  --public-url http://<public-ip-or-dns>:53550
  --fresh-host | --reuse-host

Optional:
  --user demos
  --repo-dir /home/demos/node
  --identity-file /home/demos/.secrets/demos-mnemonic
  --monitoring-profile basic|full
  --metrics-port 9090
  --prometheus-port 9091
  --grafana-port 3000
  --node-exporter-port 9100
  --json
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
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
	--user)
		USER_NAME="${2:-}"
		shift 2
		;;
	--repo-dir)
		REPO_DIR="${2:-}"
		shift 2
		;;
	--identity-file)
		IDENTITY_FILE="${2:-}"
		shift 2
		;;
	--monitoring-profile)
		MONITORING_PROFILE="${2:-}"
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
	--json)
		OUTPUT_JSON=true
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

REPO_DIR="${REPO_DIR:-/home/${USER_NAME}/node}"

failures=0
warnings=0
EVENTS_FILE="$(mktemp)"
trap 'rm -f "${EVENTS_FILE}"' EXIT

service_exists=false
repo_exists=false
containers_exist=false
docker_installed=false
bun_installed=false
rust_installed=false
apt_healthy=false
reboot_required=false
identity_present=false
classification="unknown"
recommended_strategy="unknown"
host_summary=""

record_event() {
	printf '%s\t%s\n' "$1" "$2" >>"${EVENTS_FILE}"
}

pass() {
	record_event "PASS" "$1"
	if [[ "${OUTPUT_JSON}" != "true" ]]; then
		printf 'PASS %s\n' "$1"
	fi
}

warn() {
	record_event "WARN" "$1"
	if [[ "${OUTPUT_JSON}" != "true" ]]; then
		printf 'WARN %s\n' "$1"
	fi
	warnings=$((warnings + 1))
}

fail() {
	record_event "FAIL" "$1"
	if [[ "${OUTPUT_JSON}" != "true" ]]; then
		printf 'FAIL %s\n' "$1" >&2
	fi
	failures=$((failures + 1))
}

check_port_free() {
	local port="$1"
	if ss -ltn "( sport = :${port} )" 2>/dev/null | grep -q LISTEN; then
		return 1
	fi
	if ss -lun "( sport = :${port} )" 2>/dev/null | grep -q UNCONN; then
		return 1
	fi
	return 0
}

check_https() {
	local url="$1"
	curl -fsSIL --max-time 10 "$url" >/dev/null 2>&1
}

if dpkg --audit >/dev/null 2>&1 && apt-get -qq update >/dev/null 2>&1; then
	apt_healthy=true
	pass "package manager health is acceptable"
else
	fail "package manager is not healthy enough for autonomous install"
fi

if command -v docker >/dev/null 2>&1; then
	docker_installed=true
	pass "docker is installed"
else
	warn "docker is not installed"
fi

if command -v bun >/dev/null 2>&1 || [[ -x "/home/${USER_NAME}/.bun/bin/bun" ]]; then
	bun_installed=true
	pass "bun is installed or already present for the service user"
else
	warn "bun is not installed"
fi

if command -v cargo >/dev/null 2>&1 || [[ -x "/home/${USER_NAME}/.cargo/bin/cargo" ]]; then
	rust_installed=true
	pass "rust/cargo is installed or already present for the service user"
else
	warn "rust/cargo is not installed"
fi

if [[ -f /var/run/reboot-required ]]; then
	reboot_required=true
	warn "host reports reboot-required"
fi

if [[ "$(id -u)" -ne 0 ]]; then
	fail "must run as root"
fi

if [[ -z "${PUBLIC_URL}" ]]; then
	fail "--public-url is required"
fi

if [[ -z "${HOST_MODE}" ]]; then
	fail "choose exactly one of --fresh-host or --reuse-host"
fi

if [[ "${MONITORING_PROFILE}" != "basic" && "${MONITORING_PROFILE}" != "full" ]]; then
	fail "--monitoring-profile must be basic or full"
fi

if [[ "${PUBLIC_URL}" =~ ^https?://(127\.0\.0\.1|localhost|0\.0\.0\.0)(:|/|$) ]]; then
	fail "public URL cannot use localhost, 127.0.0.1, or 0.0.0.0"
else
	pass "public URL is not loopback"
fi

ram_gb=$(( $(awk '/MemTotal/ {print $2}' /proc/meminfo) / 1024 / 1024 ))
if (( ram_gb < 4 )); then
	fail "RAM ${ram_gb}GB is below the 4GB minimum"
else
	pass "RAM ${ram_gb}GB"
fi

cpu_cores=$(nproc)
if (( cpu_cores < 4 )); then
	fail "CPU cores ${cpu_cores} is below the 4-core minimum"
else
	pass "CPU cores ${cpu_cores}"
fi

if check_https "https://github.com"; then
	pass "outbound HTTPS to github.com"
else
	fail "cannot reach https://github.com"
fi

if check_https "https://bun.sh"; then
	pass "outbound HTTPS to bun.sh"
else
	fail "cannot reach https://bun.sh"
fi

if check_https "https://download.docker.com"; then
	pass "outbound HTTPS to download.docker.com"
else
	fail "cannot reach https://download.docker.com"
fi

for port in 5332 53550 "${METRICS_PORT}" "${PROMETHEUS_PORT}" "${GRAFANA_PORT}"; do
	if [[ "${HOST_MODE}" == "fresh" ]]; then
		if check_port_free "${port}"; then
			pass "port ${port} is free"
		else
			fail "port ${port} is already in use on a fresh-host path"
		fi
	else
		if check_port_free "${port}"; then
			pass "port ${port} is free"
		else
			warn "port ${port} is already in use and will rely on reuse-host replacement semantics"
		fi
	fi
done

if [[ "${MONITORING_PROFILE}" == "full" ]]; then
	if [[ "${HOST_MODE}" == "fresh" ]]; then
		if check_port_free "${NODE_EXPORTER_PORT}"; then
			pass "node-exporter port ${NODE_EXPORTER_PORT} is free"
		else
			fail "node-exporter port ${NODE_EXPORTER_PORT} is already in use on a fresh-host path"
		fi
	fi
fi

if [[ -n "${IDENTITY_FILE}" ]]; then
	if [[ -f "${IDENTITY_FILE}" ]]; then
		identity_present=true
		pass "identity file exists at ${IDENTITY_FILE}"
	else
		fail "identity file not found at ${IDENTITY_FILE}"
	fi
fi

if [[ "${HOST_MODE}" == "fresh" ]]; then
	if systemctl list-unit-files demos-node.service --no-legend 2>/dev/null | grep -q '^demos-node\.service'; then
		service_exists=true
		fail "demos-node.service already exists on fresh-host path"
	else
		pass "no existing demos-node.service"
	fi

	if [[ -e "${REPO_DIR}" ]]; then
		repo_exists=true
		fail "repo path already exists at ${REPO_DIR} on fresh-host path"
	else
		pass "repo path is absent"
	fi

	if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -Eq '^(postgres_5332|tlsn-notary-7047|demos-prometheus|demos-grafana|demos-node-exporter)$'; then
		containers_exist=true
		fail "DEMOS-related containers already exist on fresh-host path"
	else
		pass "no DEMOS-related containers found"
	fi
else
	if systemctl list-unit-files demos-node.service --no-legend 2>/dev/null | grep -q '^demos-node\.service'; then
		service_exists=true
		warn "existing demos-node.service detected and will be replaced"
	else
		pass "no existing demos-node.service"
	fi

	if [[ -e "${REPO_DIR}" ]]; then
		repo_exists=true
		warn "repo path already exists and will be replaced"
	else
		pass "repo path is absent"
	fi

	if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -Eq '^(postgres_5332|tlsn-notary-7047|demos-prometheus|demos-grafana|demos-node-exporter)$'; then
		containers_exist=true
		warn "DEMOS-related containers already exist and will be replaced"
	else
		pass "no DEMOS-related containers found"
	fi
fi

if [[ "${apt_healthy}" != "true" ]]; then
	classification="broken_package_manager"
	recommended_strategy="abort_requires_human"
	host_summary="package manager is unhealthy"
elif [[ "${HOST_MODE}" == "fresh" && ( "${service_exists}" == "true" || "${repo_exists}" == "true" || "${containers_exist}" == "true" ) ]]; then
	classification="residue_present"
	recommended_strategy="abort_and_require_reuse_mode"
	host_summary="fresh-host path found existing DEMOS residue"
elif [[ "${service_exists}" == "true" || "${repo_exists}" == "true" || "${containers_exist}" == "true" ]]; then
	classification="existing_demos_install"
	recommended_strategy="replace_existing_install"
	host_summary="existing DEMOS footprint detected"
elif [[ "${docker_installed}" != "true" || "${bun_installed}" != "true" || "${rust_installed}" != "true" ]]; then
	classification="stale_or_partial_host"
	recommended_strategy="repair_runtime_then_install"
	host_summary="runtime components are missing or partial"
else
	classification="fresh_candidate"
	recommended_strategy="fresh_install"
	host_summary="host looks ready for a clean install"
fi

if [[ "${OUTPUT_JSON}" == "true" ]]; then
	python3 - "${EVENTS_FILE}" "${failures}" "${warnings}" "${PUBLIC_URL}" "${HOST_MODE}" "${MONITORING_PROFILE}" \
		"${classification}" "${recommended_strategy}" "${host_summary}" "${service_exists}" "${repo_exists}" \
		"${containers_exist}" "${docker_installed}" "${bun_installed}" "${rust_installed}" "${apt_healthy}" \
		"${reboot_required}" "${identity_present}" "${REPO_DIR}" "${IDENTITY_FILE}" <<'PY'
import json
import sys

events_file = sys.argv[1]
data = {
    "summary": {
        "failures": int(sys.argv[2]),
        "warnings": int(sys.argv[3]),
        "classification": sys.argv[7],
        "recommended_strategy": sys.argv[8],
        "host_summary": sys.argv[9],
    },
    "inputs": {
        "public_url": sys.argv[4],
        "host_mode": sys.argv[5],
        "monitoring_profile": sys.argv[6],
        "repo_dir": sys.argv[19],
        "identity_file": sys.argv[20],
    },
    "state": {
        "service_exists": sys.argv[10] == "true",
        "repo_exists": sys.argv[11] == "true",
        "containers_exist": sys.argv[12] == "true",
        "docker_installed": sys.argv[13] == "true",
        "bun_installed": sys.argv[14] == "true",
        "rust_installed": sys.argv[15] == "true",
        "apt_healthy": sys.argv[16] == "true",
        "reboot_required": sys.argv[17] == "true",
        "identity_present": sys.argv[18] == "true",
    },
    "events": [],
}
with open(events_file, "r", encoding="utf-8") as fh:
    for line in fh:
        level, message = line.rstrip("\n").split("\t", 1)
        data["events"].append({"level": level, "message": message})
print(json.dumps(data, indent=2))
PY
else
	printf '\nSummary: failures=%s warnings=%s classification=%s strategy=%s\n' \
		"${failures}" "${warnings}" "${classification}" "${recommended_strategy}"
fi

if (( failures > 0 )); then
	exit 1
fi
