#!/usr/bin/env python3
"""Maven Nexus — docker compose bootstrap."""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def log(level: str, msg: str) -> None:
    print(f"[{level}] {msg}")


def run(cmd: list[str]) -> None:
    log("INFO", " ".join(cmd))
    subprocess.run(cmd, cwd=ROOT, check=True, text=True)


def compose(*args: str) -> None:
    run(["docker", "compose", "-f", str(ROOT / "compose.yml"), *args])


def parse_env() -> dict[str, str]:
    env: dict[str, str] = {}
    for line in (ROOT / ".env").read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        env[key.strip()] = val.strip()
    return env


def prepare() -> None:
    env, example = ROOT / ".env", ROOT / ".env.example"
    if not env.exists():
        if not example.exists():
            sys.exit("[ERROR] .env.example missing")
        shutil.copy(example, env)
    (ROOT / "data/nexus-data").mkdir(parents=True, exist_ok=True)
    run([
        "docker", "run", "--rm",
        "-v", f"{ROOT / 'data/nexus-data'}:/nexus-data",
        "alpine", "chown", "-R", "200:200", "/nexus-data",
    ])


def cmd_up() -> None:
    if not shutil.which("docker"):
        sys.exit("[ERROR] docker required")
    run(["docker", "compose", "version"])
    prepare()
    compose("pull")
    compose("up", "-d")
    env = parse_env()
    print(f"Nexus:  {env.get('NEXUS_URL', 'http://localhost:8081')}")
    print("Pass:   cat data/nexus-data/admin.password")
    log("OK", "Started")


def main() -> None:
    parser = argparse.ArgumentParser(description="Maven Nexus")
    sub = parser.add_subparsers(dest="cmd")
    sub.add_parser("init")
    sub.add_parser("up")
    sub.add_parser("ps")
    sub.add_parser("down")
    sub.add_parser("logs")
    args = parser.parse_args()
    cmd = args.cmd or "up"

    if cmd == "init":
        prepare()
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
