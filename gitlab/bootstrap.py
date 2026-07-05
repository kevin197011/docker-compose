#!/usr/bin/env python3
"""GitLab CE — docker compose bootstrap."""
from __future__ import annotations

import argparse
import re
import secrets
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent

DIRS = (
    "data/postgresql", "data/redis-cache", "data/redis-persistent", "data/redis-sessions",
    "data/gitlab/config", "data/gitlab/log", "data/gitlab/data", "data/gitlab/backups",
    "data/gitlab-runner/config", "config/certs",
)


def log(level: str, msg: str) -> None:
    print(f"[{level}] {msg}")


def run(cmd: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    log("INFO", " ".join(cmd))
    return subprocess.run(cmd, cwd=ROOT, check=check, text=True)


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


def init_env() -> None:
    env_file = ROOT / ".env"
    if env_file.exists():
        return
    pg_data = ROOT / "data/postgresql"
    if pg_data.exists() and any(pg_data.iterdir()):
        sys.exit("[ERROR] data/postgresql exists but .env missing")

    example = ROOT / ".env.example"
    if not example.exists():
        sys.exit("[ERROR] .env.example missing")

    root_pass = secrets.token_hex(16)
    pg_pass = secrets.token_hex(16)
    redis_pass = secrets.token_hex(16)
    text = example.read_text()
    for key, val in (
        ("GITLAB_ROOT_PASSWORD", root_pass),
        ("POSTGRES_PASSWORD", pg_pass),
        ("GITLAB_REDIS_PASSWORD", redis_pass),
    ):
        text = re.sub(rf"^{key}=.*$", f"{key}={val}", text, count=1, flags=re.M)

    env_file.write_text(text)
    env_file.chmod(0o600)
    (ROOT / "data").mkdir(parents=True, exist_ok=True)
    creds = ROOT / "data/.credentials"
    creds.write_text(
        f"# Generated {datetime.now(timezone.utc).isoformat()}\n"
        f"GITLAB_ROOT_PASSWORD={root_pass}\n"
        f"POSTGRES_PASSWORD={pg_pass}\n"
        f"GITLAB_REDIS_PASSWORD={redis_pass}\n"
    )
    creds.chmod(0o600)
    log("OK", "Created .env")


def setup() -> None:
    init_env()
    for d in DIRS:
        (ROOT / d).mkdir(parents=True, exist_ok=True)
    env = parse_env()
    if env.get("GITLAB_LISTEN_HTTPS", "false").lower() == "true":
        cert = ROOT / "config/certs" / env.get("GITLAB_SSL_CERT", "gitlab.devops.com.crt")
        key = ROOT / "config/certs" / env.get("GITLAB_SSL_KEY", "gitlab.devops.com.key")
        if not cert.exists() or not key.exists():
            log("WARN", f"HTTPS enabled but missing {cert.name} or {key.name}")


def runner_ready() -> bool:
    cfg = ROOT / "data/gitlab-runner/config/config.toml"
    return cfg.exists() and "glrt-" in cfg.read_text()


def register_runner() -> None:
    env = parse_env()
    cfg = ROOT / "data/gitlab-runner/config/config.toml"
    url = env.get("GITLAB_INTERNAL_URL") or env.get("GITLAB_URL", "http://gitlab")
    cert = ROOT / "config/certs" / env.get("GITLAB_SSL_CERT", "gitlab.devops.com.crt")
    tls_ca = "/etc/gitlab-runner/certs/ca.crt"

    if runner_ready():
        if cfg.exists() and 'url = "http://gitlab"' in cfg.read_text() and url.startswith("https://"):
            text = cfg.read_text()
            text = text.replace('url = "http://gitlab"', f'url = "{url}"')
            text = text.replace('clone_url = "http://gitlab"', f'clone_url = "{url}"')
            if "tls-ca-file" not in text:
                text = text.replace(f'  url = "{url}"', f'  url = "{url}"\n  tls-ca-file = "{tls_ca}"', 1)
            cfg.write_text(text)
            log("OK", "Updated runner URL")
        return

    log("INFO", "Registering GitLab runner...")
    for _ in range(60):
        r = subprocess.run(
            ["docker", "exec", "gitlab", "gitlab-rails", "runner", "puts :ok"],
            capture_output=True, text=True,
        )
        if "ok" in r.stdout:
            break
        time.sleep(5)
    else:
        sys.exit("[ERROR] GitLab not ready for runner registration")

    name = env.get("GITLAB_RUNNER_NAME", "gitlab-shared-runner")
    tags = env.get("GITLAB_RUNNER_TAG_LIST", "docker,shared")
    image = f"gitlab/gitlab-runner:{env.get('GITLAB_RUNNER_VERSION', 'alpine-v18.11.4')}"
    rails = f"""
    r = Ci::Runners::CreateRunnerService.new(
      user: User.find_by(username: 'root'),
      params: {{
        runner_type: 'instance_type',
        description: '{name}',
        tag_list: '{tags}',
        run_untagged: true,
        locked: false
      }}
    ).execute
    raise r.message unless r.success?
    puts r.payload[:runner].token
    """
    r = subprocess.run(
        ["docker", "exec", "gitlab", "gitlab-rails", "runner", rails],
        capture_output=True, text=True,
    )
    token = next((ln.strip() for ln in r.stdout.splitlines() if ln.strip().startswith("glrt-")), "")
    if not token:
        sys.exit("[ERROR] Failed to create runner token")

    cmd = [
        "docker", "run", "--rm", "--network", "gitlab_net",
        "-v", f"{ROOT / 'data/gitlab-runner/config'}:/etc/gitlab-runner",
        "-v", "/var/run/docker.sock:/var/run/docker.sock",
    ]
    if url.startswith("https://") and cert.exists():
        cmd += ["-v", f"{cert}:{tls_ca}:ro"]
    cmd += [
        image, "register", "--non-interactive",
        "--url", url, "--clone-url", url, "--token", token,
        "--executor", "docker", "--description", name,
        "--docker-image", "docker:27-alpine",
        "--docker-volumes", "/var/run/docker.sock:/var/run/docker.sock",
        "--docker-volumes", "/cache",
        "--docker-network-mode", "gitlab_net",
        "--docker-privileged",
    ]
    if url.startswith("https://") and cert.exists():
        cmd += ["--tls-ca-file", tls_ca]
    run(cmd)
    cfg.chmod(0o644)
    log("OK", "Runner registered")


def reload_certs() -> None:
    env = parse_env()
    if env.get("GITLAB_LISTEN_HTTPS", "false").lower() != "true":
        return
    cert = ROOT / "config/certs" / env.get("GITLAB_SSL_CERT", "gitlab.devops.com.crt")
    key = ROOT / "config/certs" / env.get("GITLAB_SSL_KEY", "gitlab.devops.com.key")
    if not cert.exists() or not key.exists():
        return
    r = subprocess.run(["docker", "ps", "--format", "{{.Names}}"], capture_output=True, text=True)
    if "gitlab" not in r.stdout.split():
        return
    subprocess.run(["docker", "exec", "gitlab", "gitlab-ctl", "hup", "nginx"], check=False)
    log("OK", "HTTPS certs reloaded")


def cmd_up() -> None:
    if not shutil.which("docker"):
        sys.exit("[ERROR] docker required")
    run(["docker", "compose", "version"])
    setup()
    compose("pull")
    if not runner_ready():
        compose("up", "-d", "postgresql", "redis-cache", "redis-persistent", "redis-sessions", "gitlab")
        register_runner()
    compose("up", "-d")
    register_runner()
    reload_certs()
    env = parse_env()
    print(f"URL:  {env.get('GITLAB_URL', '')}")
    print("Root: cat data/.credentials")
    log("OK", "GitLab started")


def main() -> None:
    parser = argparse.ArgumentParser(description="GitLab")
    sub = parser.add_subparsers(dest="cmd")
    sub.add_parser("init")
    sub.add_parser("up")
    sub.add_parser("ps")
    sub.add_parser("down")
    sub.add_parser("logs")
    args = parser.parse_args()
    cmd = args.cmd or "up"

    if cmd == "init":
        setup()
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
