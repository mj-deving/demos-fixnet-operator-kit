#!/usr/bin/env python3
import json
import os
import shutil
import stat
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SCENARIOS = ROOT / "tests" / "dirty-host" / "scenarios"
PREFLIGHT = ROOT / "scripts" / "preflight_fixnet_host.sh"
PUBLIC_URL = "http://203.0.113.10:53550"


def write_executable(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def link_binary(bindir: Path, name: str) -> None:
    target = shutil.which(name)
    if not target:
        raise SystemExit(f"required binary not found: {name}")
    (bindir / name).symlink_to(target)


def build_stub_bin(tmpdir: Path, scenario: dict) -> Path:
    bindir = tmpdir / "bin"
    bindir.mkdir(parents=True, exist_ok=True)

    for binary in ("bash", "python3", "awk", "grep", "head", "sort", "git", "mktemp", "nproc", "find", "dirname", "rm", "cat"):
        link_binary(bindir, binary)

    write_executable(
        bindir / "id",
        """#!/usr/bin/env bash
if [[ "${1:-}" == "-u" ]]; then
  echo 0
  exit 0
fi
/usr/bin/id "$@"
""",
    )

    apt_healthy = "true" if scenario["apt_healthy"] else "false"
    write_executable(
        bindir / "dpkg",
        f"""#!/usr/bin/env bash
if [[ "${{1:-}}" == "--audit" ]]; then
  [[ "{apt_healthy}" == "true" ]] && exit 0 || exit 1
fi
exit 0
""",
    )
    write_executable(
        bindir / "apt-get",
        f"""#!/usr/bin/env bash
if [[ "{apt_healthy}" == "true" ]]; then
  exit 0
fi
exit 1
""",
    )

    write_executable(
        bindir / "curl",
        """#!/usr/bin/env bash
url="${@: -1}"
case "${url}" in
  https://github.com|https://bun.sh|https://download.docker.com)
    exit 0
    ;;
  *)
    exit 1
    ;;
esac
""",
    )

    busy_ports = " ".join(str(port) for port in scenario["busy_ports"])
    write_executable(
        bindir / "ss",
        f"""#!/usr/bin/env bash
args="$*"
for port in {busy_ports}; do
  if [[ "$args" == *":$port"* ]]; then
    echo "LISTEN 0 128 0.0.0.0:$port 0.0.0.0:*"
    exit 0
  fi
done
exit 0
""",
    )

    service_exists = "true" if scenario["service_exists"] else "false"
    service_active = "true" if scenario["existing_service_active"] else "false"
    write_executable(
        bindir / "systemctl",
        f"""#!/usr/bin/env bash
if [[ "${{1:-}}" == "list-unit-files" ]]; then
  if [[ "{service_exists}" == "true" ]]; then
    echo "demos-node.service enabled"
  fi
  exit 0
fi
if [[ "${{1:-}}" == "is-active" ]]; then
  if [[ "{service_active}" == "true" ]]; then
    echo active
    exit 0
  fi
  echo inactive
  exit 3
fi
exit 0
""",
    )

    if scenario["docker_installed"]:
        docker_version = scenario["docker_version"]
        docker_compose_ok = "true" if scenario["docker_compose_ok"] else "false"
        container_names = ["postgres_5332", "tlsn-notary-7047", "demos-prometheus"] if scenario["containers_exist"] else []
        container_text = "\\n".join(container_names)
        write_executable(
            bindir / "docker",
            f"""#!/usr/bin/env bash
if [[ "${{1:-}}" == "version" ]]; then
  echo "{docker_version}"
  exit 0
fi
if [[ "${{1:-}}" == "compose" && "${{2:-}}" == "version" ]]; then
  [[ "{docker_compose_ok}" == "true" ]] && exit 0 || exit 1
fi
if [[ "${{1:-}}" == "ps" ]]; then
  cat <<'EOF'
{container_text}
EOF
  exit 0
fi
exit 0
""",
        )

    if scenario["bun_installed"]:
        write_executable(
            bindir / "bun",
            f"""#!/usr/bin/env bash
echo "{scenario['bun_version']}"
""",
        )

    if scenario["rust_installed"]:
        write_executable(
            bindir / "cargo",
            f"""#!/usr/bin/env bash
echo "cargo {scenario['rust_version']} (fake)"
""",
        )

    return bindir


def create_repo(tmpdir: Path, scenario: dict) -> tuple[Path, Path]:
    home_dir = tmpdir / "home" / "demos"
    repo_dir = home_dir / "node"
    secrets_dir = home_dir / ".secrets"
    secrets_dir.mkdir(parents=True, exist_ok=True)

    if scenario["identity_present"]:
        (secrets_dir / "demos-mnemonic").write_text("test words only\n", encoding="utf-8")

    if scenario["repo_exists"]:
        repo_dir.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "-C", str(repo_dir), "init", "-q"], check=True)
        subprocess.run(["git", "-C", str(repo_dir), "config", "user.email", "dirty-host@example.com"], check=True)
        subprocess.run(["git", "-C", str(repo_dir), "config", "user.name", "Dirty Host"], check=True)
        (repo_dir / "README.md").write_text("dirty host fixture\n", encoding="utf-8")
        subprocess.run(["git", "-C", str(repo_dir), "add", "README.md"], check=True)
        subprocess.run(["git", "-C", str(repo_dir), "commit", "-qm", "init"], check=True)
        branch = scenario["existing_branch"] or "stabilisation"
        subprocess.run(["git", "-C", str(repo_dir), "checkout", "-q", "-B", branch], check=True)

    return repo_dir, secrets_dir / "demos-mnemonic"


def run_scenario(path: Path) -> None:
    scenario = json.loads(path.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory(prefix=f"dirty-host-{scenario['name']}-") as tmp:
        tmpdir = Path(tmp)
        repo_dir, identity_file = create_repo(tmpdir, scenario)
        bindir = build_stub_bin(tmpdir, scenario)
        env = os.environ.copy()
        env["PATH"] = str(bindir)
        cmd = [
            str(PREFLIGHT),
            "--public-url",
            PUBLIC_URL,
            f"--{scenario['host_mode']}-host",
            "--repo-dir",
            str(repo_dir),
            "--json",
        ]
        if scenario["identity_present"]:
            cmd.extend(["--identity-file", str(identity_file)])

        result = subprocess.run(cmd, capture_output=True, text=True, env=env)
        if result.returncode != scenario["expected_exit_code"]:
            raise SystemExit(
                f"{path.name}: expected exit {scenario['expected_exit_code']}, got {result.returncode}\n"
                f"stdout:\n{result.stdout}\n\nstderr:\n{result.stderr}"
            )
        payload = json.loads(result.stdout)
        for key, value in scenario["expected"].items():
            actual = payload["summary"][key]
            if actual != value:
                raise SystemExit(f"{path.name}: expected {key}={value!r}, got {actual!r}")


def main() -> int:
    scenario_paths = sorted(SCENARIOS.glob("*.json"))
    if not scenario_paths:
        raise SystemExit("No dirty-host scenarios found")
    for path in scenario_paths:
        run_scenario(path)
    print(f"validated {len(scenario_paths)} dirty-host scenarios")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
