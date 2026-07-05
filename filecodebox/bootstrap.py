#!/usr/bin/env python3
"""FileCodeBox — docker compose bootstrap."""
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


def prepare() -> None:
    (ROOT / "data/filecodebox").mkdir(parents=True, exist_ok=True)


def cmd_up() -> None:
    if not shutil.which("docker"):
        sys.exit("[ERROR] docker required")
    run(["docker", "compose", "version"])
    prepare()
    compose("pull")
    compose("up", "-d")
    log("OK", "Started")


def main() -> None:
    parser = argparse.ArgumentParser(description="FileCodeBox")
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
