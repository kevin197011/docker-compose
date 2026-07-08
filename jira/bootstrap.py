#!/usr/bin/env python3
"""Jira — docker compose bootstrap."""
from __future__ import annotations

import argparse
import secrets
import shutil
import subprocess
import sys
from pathlib import Path
from string import Template

ROOT = Path(__file__).resolve().parent
AGENT_JAR = ROOT / "atlassian-agent.jar"
AGENT_CONFLUENCE_JAR = ROOT.parent / "confluence" / "atlassian-agent.jar"
AGENT_BUILD_JAR = ROOT.parent.parent / "atlassian-agent" / "target" / "atlassian-agent-jar-with-dependencies.jar"


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


def ensure_agent_jar() -> None:
    if AGENT_JAR.exists():
        return
    if AGENT_CONFLUENCE_JAR.exists():
        shutil.copy(AGENT_CONFLUENCE_JAR, AGENT_JAR)
        log("OK", f"Copied {AGENT_CONFLUENCE_JAR} -> {AGENT_JAR.name}")
        return
    if AGENT_BUILD_JAR.exists():
        shutil.copy(AGENT_BUILD_JAR, AGENT_JAR)
        log("OK", f"Copied {AGENT_BUILD_JAR} -> {AGENT_JAR.name}")
        return
    sys.exit(
        f"[ERROR] missing {AGENT_JAR.name}; build atlassian-agent or start confluence first"
    )


def ensure_upm_config() -> None:
    upm_dir = ROOT / "config" / "upmconfig"
    truststore = upm_dir / "truststore"
    props = upm_dir / "upm.properties"
    truststore.mkdir(parents=True, exist_ok=True)
    if not props.exists():
        props.write_text("atlassian.upm.signature.check.disabled=true\n")
    props.chmod(0o444)
    upm_dir.chmod(0o755)
    truststore.chmod(0o755)
    log("OK", f"UPM config at {upm_dir.relative_to(ROOT)}")


def prepare() -> None:
    for d in ("data", "logs", "config"):
        (ROOT / d).mkdir(parents=True, exist_ok=True)
    ensure_agent_jar()
    ensure_upm_config()
    env = ROOT / ".env"
    if not env.exists():
        example = ROOT / ".env.example"
        if not example.exists():
            sys.exit("[ERROR] .env.example missing")
        shutil.copy(example, env)
        pwd = secrets.token_hex(16)
        lines = []
        for line in env.read_text().splitlines():
            if line.startswith("POSTGRES_PASSWORD="):
                lines.append(f"POSTGRES_PASSWORD={pwd}")
            else:
                lines.append(line)
        env.write_text("\n".join(lines) + "\n")
    variables = parse_env()
    for name in ("nginx.conf",):
        tmpl = ROOT / "templates" / f"{name}.tmpl"
        if tmpl.exists():
            (ROOT / "config" / name).write_text(Template(tmpl.read_text()).safe_substitute(variables))
            log("OK", f"Wrote config/{name}")


def cmd_up() -> None:
    if not shutil.which("docker"):
        sys.exit("[ERROR] docker required")
    run(["docker", "compose", "version"])
    prepare()
    compose("pull")
    compose("up", "-d")
    log("OK", "Started")


def main() -> None:
    parser = argparse.ArgumentParser(description="Jira")
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
