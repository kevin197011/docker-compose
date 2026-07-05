#!/usr/bin/env python3
"""Harbor Docker Compose bootstrap — https://goharbor.io/docs/2.15.0/install-config/"""

from __future__ import annotations

import argparse
import platform
import secrets
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def log(level: str, msg: str) -> None:
    print(f"[{level}] {msg}")


def run(cmd: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    log("INFO", " ".join(cmd))
    return subprocess.run(cmd, check=check, text=True)


def parse_env(path: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        env[key.strip()] = val.strip()
    return env


def as_bool(val: str, default: bool = False) -> bool:
    if not val:
        return default
    return val.lower() in {"1", "true", "yes", "on"}


def load_cfg() -> dict[str, str]:
    env_file = ROOT / ".env"
    if not env_file.exists():
        sys.exit("[ERROR] .env missing — run: python bootstrap.py init")
    raw = parse_env(env_file)
    hostname = raw.get("HARBOR_HOSTNAME", "")
    for key in ("HARBOR_VERSION", "HARBOR_HOSTNAME", "HARBOR_ADMIN_PASSWORD", "HARBOR_DB_PASSWORD"):
        if not raw.get(key):
            sys.exit(f"[ERROR] {key} required in .env")

    cert_name = raw.get("HARBOR_SSL_CERT") or f"{hostname}.crt"
    key_name = raw.get("HARBOR_SSL_KEY") or f"{hostname}.key"
    return {
        "version": raw["HARBOR_VERSION"],
        "hostname": hostname,
        "url": raw.get("HARBOR_URL") or f"https://{hostname}",
        "http_port": raw.get("HARBOR_HTTP_PORT", "80"),
        "https_port": raw.get("HARBOR_HTTPS_PORT", "443"),
        "https": str(as_bool(raw.get("HARBOR_HTTPS", "true"), True)).lower(),
        "admin_password": raw["HARBOR_ADMIN_PASSWORD"],
        "db_password": raw["HARBOR_DB_PASSWORD"],
        "job_workers": raw.get("HARBOR_JOBSERVICE_MAX_WORKERS", "10"),
        "cache_enabled": str(as_bool(raw.get("HARBOR_CACHE_ENABLED", "true"), True)).lower(),
        "cache_expire_hours": raw.get("HARBOR_CACHE_EXPIRE_HOURS", "24"),
        "log_level": raw.get("HARBOR_LOG_LEVEL", "info"),
        "trivy_skip_update": str(as_bool(raw.get("HARBOR_TRIVY_SKIP_UPDATE", "false"))).lower(),
        "trivy_github_token": raw.get("HARBOR_TRIVY_GITHUB_TOKEN", ""),
        "data_dir": str(ROOT / "data"),
        "log_dir": str(ROOT / "logs"),
        "cert_path": str(ROOT / "config/certs" / cert_name),
        "key_path": str(ROOT / "config/certs" / key_name),
    }


def init_env() -> None:
    example = ROOT / ".env.example"
    env_file = ROOT / ".env"
    data_dir = ROOT / "data"

    if env_file.exists():
        log("INFO", ".env already exists")
        return
    if data_dir.exists() and any(data_dir.iterdir()):
        sys.exit("[ERROR] data/ exists but .env missing")

    admin_pass = secrets.token_hex(16)
    db_pass = secrets.token_hex(16)
    text = example.read_text()
    text = text.replace("HARBOR_ADMIN_PASSWORD=change-me-admin-password", f"HARBOR_ADMIN_PASSWORD={admin_pass}")
    text = text.replace("HARBOR_DB_PASSWORD=change-me-db-password", f"HARBOR_DB_PASSWORD={db_pass}")
    env_file.write_text(text)
    env_file.chmod(0o600)

    data_dir.mkdir(parents=True, exist_ok=True)
    creds = ROOT / "data" / ".credentials"
    creds.write_text(
        f"# Generated {datetime.now(timezone.utc).isoformat()} — keep secret\n"
        f"HARBOR_ADMIN_PASSWORD={admin_pass}\n"
        f"HARBOR_DB_PASSWORD={db_pass}\n"
    )
    creds.chmod(0o600)
    log("OK", "Created .env and data/.credentials")


def ensure_dirs() -> None:
    for d in ("data", "logs", "config/certs", "config/harbor"):
        (ROOT / d).mkdir(parents=True, exist_ok=True)


def ensure_certs(cfg: dict[str, str]) -> None:
    if cfg["https"] != "true":
        return
    cert, key = Path(cfg["cert_path"]), Path(cfg["key_path"])
    if cert.exists() and key.exists():
        return
    log("INFO", f"Generating self-signed cert for {cfg['hostname']}")
    cmd = [
        "openssl", "req", "-x509", "-nodes", "-days", "825", "-newkey", "rsa:4096",
        "-keyout", str(key), "-out", str(cert),
        "-subj", f"/CN={cfg['hostname']}",
    ]
    try:
        run(cmd + ["-addext", f"subjectAltName=DNS:{cfg['hostname']}"], check=True)
    except subprocess.CalledProcessError:
        run(cmd, check=True)
    key.chmod(0o600)
    log("OK", f"Created {cert}")


def render_harbor_yml(cfg: dict[str, str]) -> Path:
    https_block = ""
    if cfg["https"] == "true":
        https_block = f"""
https:
  port: {cfg['https_port']}
  certificate: {cfg['cert_path']}
  private_key: {cfg['key_path']}
"""

    trivy_token = ""
    if cfg["trivy_github_token"]:
        trivy_token = f"\n  github_token: {cfg['trivy_github_token']}"

    content = f"""# Harbor {cfg['version']} — generated by bootstrap.py
hostname: {cfg['hostname']}

http:
  port: {cfg['http_port']}
{https_block}
harbor_admin_password: {cfg['admin_password']}

database:
  password: {cfg['db_password']}
  max_idle_conns: 100
  max_open_conns: 900
  conn_max_lifetime: 5m
  conn_max_idle_time: 0

data_volume: {cfg['data_dir']}

trivy:
  ignore_unfixed: false
  skip_update: {cfg['trivy_skip_update']}
  skip_java_db_update: false
  db_repository: ghcr.io/aquasecurity/trivy-db
  java_db_repository: ghcr.io/aquasecurity/trivy-java-db
  offline_scan: false
  security_check: vuln
  insecure: false
  timeout: 5m0s{trivy_token}

jobservice:
  max_job_workers: {cfg['job_workers']}
  max_job_duration_hours: 24
  job_loggers:
    - STD_OUTPUT
    - FILE
  logger_sweeper_duration: 1

notification:
  webhook_job_max_retry: 3
  webhook_job_http_client_timeout: 3

log:
  level: {cfg['log_level']}
  local:
    rotate_count: 50
    rotate_size: 200M
    location: {cfg['log_dir']}

_version: 2.15.0

proxy:
  http_proxy:
  https_proxy:
  no_proxy:
  components:
    - core
    - jobservice
    - trivy

upload_purging:
  enabled: true
  age: 168h
  interval: 24h
  dryrun: false

cache:
  enabled: {cfg['cache_enabled']}
  expire_hours: {cfg['cache_expire_hours']}
"""
    out = ROOT / "harbor.yml"
    out.write_text(content)
    log("OK", f"Wrote {out.name}")
    return out


def run_prepare(cfg: dict[str, str], harbor_yml: Path) -> None:
    input_dir = ROOT / "input"
    input_dir.mkdir(exist_ok=True)
    shutil.copy(harbor_yml, input_dir / "harbor.yml")

    host_base = Path.home() if platform.system() == "Darwin" else Path("/")
    run([
        "docker", "run", "--rm",
        "-v", f"{input_dir}:/input",
        "-v", f"{cfg['data_dir']}:/data",
        "-v", f"{ROOT}:/compose_location",
        "-v", f"{ROOT / 'config/harbor'}:/config",
        "-v", f"{host_base}:/hostfs{host_base}",
        "--privileged",
        f"goharbor/prepare:{cfg['version']}", "prepare", "--with-trivy",
    ])

    shutil.rmtree(input_dir)
    generated = ROOT / "docker-compose.yml"
    if not generated.exists():
        sys.exit("[ERROR] prepare did not generate docker-compose.yml")
    generated.rename(ROOT / "compose.yml")
    log("OK", "Generated compose.yml")


def compose(*args: str) -> None:
    compose_file = ROOT / "compose.yml"
    if not compose_file.exists():
        sys.exit("[ERROR] compose.yml missing — run: python bootstrap.py up")
    run(["docker", "compose", "-f", str(compose_file), *args])


def cmd_up(_: argparse.Namespace) -> None:
    for exe in ("docker", "openssl"):
        if not shutil.which(exe):
            sys.exit(f"[ERROR] {exe} required")
    run(["docker", "compose", "version"])

    init_env()
    cfg = load_cfg()
    ensure_dirs()
    ensure_certs(cfg)
    harbor_yml = render_harbor_yml(cfg)
    run_prepare(cfg, harbor_yml)
    compose("pull")
    compose("up", "-d")

    log("OK", "Harbor started")
    print(f"URL:  {cfg['url']}")
    print("User: admin")
    print("Pass: cat data/.credentials")
    if cfg["https"] != "true":
        print(f"[WARN] HTTP mode: add {cfg['hostname']}:{cfg['http_port']} to Docker insecure-registries")


def cmd_prepare(_: argparse.Namespace) -> None:
    cfg = load_cfg()
    ensure_dirs()
    ensure_certs(cfg)
    run_prepare(cfg, render_harbor_yml(cfg))
    log("OK", "Run: docker compose up -d")


def main() -> None:
    parser = argparse.ArgumentParser(description="Harbor Docker Compose bootstrap")
    sub = parser.add_subparsers(dest="cmd")

    sub.add_parser("init", help="Create .env from .env.example")
    sub.add_parser("prepare", help="Generate harbor.yml and compose.yml")
    sub.add_parser("up", help="Full deploy (default)")
    sub.add_parser("ps", help="Container status")
    sub.add_parser("down", help="Stop Harbor")
    sub.add_parser("logs", help="Follow logs")

    args = parser.parse_args()
    cmd = args.cmd or "up"

    if cmd == "init":
        init_env()
    elif cmd == "prepare":
        cmd_prepare(args)
    elif cmd == "up":
        cmd_up(args)
    elif cmd == "ps":
        compose("ps")
    elif cmd == "down":
        compose("down")
    elif cmd == "logs":
        compose("logs", "-f")


if __name__ == "__main__":
    main()
