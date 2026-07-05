#!/usr/bin/env python3
"""Authentik — docker compose bootstrap."""
from __future__ import annotations

import argparse
import secrets
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent

AUTHENTIK_ENV = """\
PG_PASS={pg_pass}
PG_USER=authentik
PG_DB=authentik
REDIS_PASS={redis_pass}
AUTHENTIK_SECRET_KEY={secret}
AUTHENTIK_ERROR_REPORTING__ENABLED=false
AUTHENTIK_POSTGRESQL__HOST=postgresql
AUTHENTIK_POSTGRESQL__USER=authentik
AUTHENTIK_POSTGRESQL__PASSWORD=authentik
AUTHENTIK_POSTGRESQL__NAME=authentik
AUTHENTIK_REDIS__HOST=redis
AUTHENTIK_REDIS__PASSWORD=authentik_redis
AUTHENTIK_PORT=9000
AUTHENTIK_PORT_API=9443
COMPOSE_PORT_HTTP=9000
COMPOSE_PORT_HTTPS=9443
AUTHENTIK_IMAGE=ghcr.io/goauthentik/server
AUTHENTIK_TAG=2025.6.3
AUTHENTIK_BOOTSTRAP_PASSWORD=admin123
AUTHENTIK_BOOTSTRAP_TOKEN=admin123
AUTHENTIK_BOOTSTRAP_EMAIL=admin@example.com
"""


def log(level: str, msg: str) -> None:
    print(f"[{level}] {msg}")


def run(cmd: list[str]) -> None:
    log("INFO", " ".join(cmd))
    subprocess.run(cmd, cwd=ROOT, check=True, text=True)


def compose(*args: str) -> None:
    run(["docker", "compose", "-f", str(ROOT / "compose.yml"), *args])


def init_env() -> None:
    for d in ("data/postgresql", "data/redis", "data/media", "config/custom-templates", "config/certs"):
        (ROOT / d).mkdir(parents=True, exist_ok=True)
    env = ROOT / ".env"
    if env.exists():
        return
    pg_pass, redis_pass = secrets.token_hex(16), secrets.token_hex(16)
    secret = secrets.token_hex(32)
    env.write_text(AUTHENTIK_ENV.format(pg_pass=pg_pass, redis_pass=redis_pass, secret=secret))
    log("OK", f"Created .env (PG_PASS={pg_pass}, REDIS_PASS={redis_pass})")


def cmd_up() -> None:
    if not shutil.which("docker"):
        sys.exit("[ERROR] docker required")
    run(["docker", "compose", "version"])
    init_env()
    compose("pull")
    compose("up", "-d")
    log("OK", "Started")


def main() -> None:
    parser = argparse.ArgumentParser(description="Authentik")
    sub = parser.add_subparsers(dest="cmd")
    sub.add_parser("init")
    sub.add_parser("up")
    sub.add_parser("ps")
    sub.add_parser("down")
    sub.add_parser("logs")
    args = parser.parse_args()
    cmd = args.cmd or "up"

    if cmd == "init":
        init_env()
        log("OK", "Init complete")
    elif cmd == "up":
        cmd_up()
    elif cmd == "ps":
        compose("ps")
    elif cmd == "down":
        compose("down")
    elif cmd == "logs":
        compose("logs", "-f")


if __name__ == "__main__":
    main()
