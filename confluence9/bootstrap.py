#!/usr/bin/env python3
"""Bootstrap Confluence 9.0.2 (haxqer) + PostgreSQL 13 stack."""

from __future__ import annotations

import os
import secrets
import string
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
IMAGE = "haxqer/confluence:9.0.2"
AGENT_IN_IMAGE = "/var/agent/atlassian-agent.jar"
AGENT_HOST = ROOT / "atlassian-agent.jar"


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    print("+", " ".join(cmd), flush=True)
    return subprocess.run(cmd, check=True, **kwargs)


def ensure_env() -> None:
    env_path = ROOT / ".env"
    example = ROOT / ".env.example"
    if env_path.exists():
        print(f"[ok] {env_path.name} exists")
        return
    if not example.exists():
        raise SystemExit("[error] missing .env.example")
    text = example.read_text(encoding="utf-8")
    alphabet = string.ascii_letters + string.digits
    pw = "".join(secrets.choice(alphabet) for _ in range(24))
    text = text.replace("change-me-strong", pw)
    env_path.write_text(text, encoding="utf-8")
    print(f"[ok] wrote {env_path.name} with random POSTGRES_PASSWORD")


def ensure_dirs() -> None:
    for rel in ("data/confluence", "data/pgsql", "config", "logs"):
        (ROOT / rel).mkdir(parents=True, exist_ok=True)
    print("[ok] data/ config/ logs/ ready")


def pull_and_extract_agent() -> None:
    run(["docker", "pull", IMAGE])
    if AGENT_HOST.exists() and AGENT_HOST.stat().st_size > 0:
        print(f"[ok] {AGENT_HOST.name} already present")
        return
    cid = subprocess.check_output(
        ["docker", "create", IMAGE], text=True
    ).strip()
    try:
        run(["docker", "cp", f"{cid}:{AGENT_IN_IMAGE}", str(AGENT_HOST)])
    finally:
        subprocess.run(["docker", "rm", "-f", cid], check=False, capture_output=True)
    if not AGENT_HOST.exists():
        raise SystemExit(f"[error] failed to extract {AGENT_IN_IMAGE}")
    print(f"[ok] extracted {AGENT_HOST.name} from {IMAGE}")


def compose_up() -> None:
    compose = ROOT / "compose.yml"
    if not compose.exists():
        raise SystemExit("[error] missing compose.yml")
    env = os.environ.copy()
    run(
        ["docker", "compose", "-f", str(compose), "up", "-d", "--pull", "missing"],
        cwd=ROOT,
        env=env,
    )
    print("[ok] stack up — open http://localhost:8090")
    print("    DB host in wizard: pgsql   port: 5432")
    print("    license: ./hack.sh   (product=conf)")


def main() -> int:
    os.chdir(ROOT)
    ensure_dirs()
    ensure_env()
    pull_and_extract_agent()
    if "--no-up" in sys.argv:
        print("[ok] bootstrap done (--no-up)")
        return 0
    compose_up()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as e:
        print(f"[error] command failed: {e}", file=sys.stderr)
        raise SystemExit(e.returncode)
