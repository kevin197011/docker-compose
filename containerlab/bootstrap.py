#!/usr/bin/env python3
"""Containerlab — run clab in Docker (Docker-out-of-Docker)."""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DIRS = ("data", "logs", "config", "labs")


def log(level: str, msg: str) -> None:
    print(f"[{level}] {msg}")


def run(cmd: list[str], *, check: bool = True) -> None:
    log("INFO", " ".join(cmd))
    subprocess.run(cmd, cwd=ROOT, check=check, text=True)


def compose(*args: str) -> None:
    run(["docker", "compose", "-f", str(ROOT / "compose.yml"), *args])


def prepare() -> None:
    for d in DIRS:
        (ROOT / d).mkdir(parents=True, exist_ok=True)
    env = ROOT / ".env"
    if not env.exists() and (ROOT / ".env.example").exists():
        shutil.copy(ROOT / ".env.example", env)


def clab_run(*args: str) -> None:
    compose("run", "--rm", "clab", *args)


def cmd_shell() -> None:
    if not shutil.which("docker"):
        sys.exit("[ERROR] docker required")
    if sys.platform != "linux":
        log("WARN", "containerlab-in-docker needs a Linux host for full networking")
    prepare()
    compose("pull")
    clab_run("bash")


def cmd_deploy(topology: str) -> None:
    if not shutil.which("docker"):
        sys.exit("[ERROR] docker required")
    topo = Path(topology)
    if not topo.is_absolute():
        topo = ROOT / topology
    if not topo.exists():
        sys.exit(f"[ERROR] topology not found: {topology}")
    prepare()
    compose("pull")
    clab_run("deploy", "-t", str(topo))


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Containerlab runner (https://containerlab.dev/install/#container)",
    )
    sub = parser.add_subparsers(dest="cmd")
    sub.add_parser("init")
    sub.add_parser("shell", help="Interactive clab shell (default)")
    deploy = sub.add_parser("deploy", help="Deploy a topology file")
    deploy.add_argument("topology", help="Path to .clab.yml, e.g. labs/example.clab.yml")
    sub.add_parser("ps")
    sub.add_parser("down")
    sub.add_parser("logs")
    args = parser.parse_args()
    cmd = args.cmd or "shell"

    if cmd == "init":
        prepare()
        log("OK", "Init complete")
    elif cmd == "shell":
        cmd_shell()
    elif cmd == "deploy":
        cmd_deploy(args.topology)
    elif cmd == "ps":
        compose("ps")
    elif cmd == "down":
        clab_run("destroy", "--all")
    elif cmd == "logs":
        compose("logs", "-f")


if __name__ == "__main__":
    main()
