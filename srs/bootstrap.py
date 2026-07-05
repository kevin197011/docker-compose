#!/usr/bin/env python3
"""SRS — docker compose bootstrap."""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent

DEFAULT_SRS_CONF = """\
listen              1935;
max_connections     1000;
daemon              off;
srs_log_tank        console;
http_server {
    enabled         on;
    listen          8080;
}
http_api {
    enabled         on;
    listen          1985;
}
rtc_server {
    enabled on;
    listen 8000;
}
vhost __defaultVhost__ {
    rtc { enabled on; }
    http_remux { enabled on; mount [vhost]/[app]/[stream].flv; }
}
"""


def log(level: str, msg: str) -> None:
    print(f"[{level}] {msg}")


def run(cmd: list[str]) -> None:
    log("INFO", " ".join(cmd))
    subprocess.run(cmd, cwd=ROOT, check=True, text=True)


def compose(*args: str) -> None:
    run(["docker", "compose", "-f", str(ROOT / "compose.yml"), *args])


def prepare() -> None:
    conf_dir = ROOT / "config/srs"
    conf_dir.mkdir(parents=True, exist_ok=True)
    (ROOT / "data").mkdir(parents=True, exist_ok=True)
    (ROOT / "logs").mkdir(parents=True, exist_ok=True)
    conf = conf_dir / "live.conf"
    if not conf.exists():
        conf.write_text(DEFAULT_SRS_CONF)
        log("OK", f"Created {conf}")


def cmd_up() -> None:
    if not shutil.which("docker"):
        sys.exit("[ERROR] docker required")
    run(["docker", "compose", "version"])
    prepare()
    compose("pull")
    compose("up", "-d")
    log("OK", "Started")


def main() -> None:
    parser = argparse.ArgumentParser(description="SRS")
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
