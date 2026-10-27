#!/usr/bin/env python3
"""Provision Cream on a remote server over SSH (password auth via pty)."""

from __future__ import annotations

import os
import pty
import select
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DEPLOY_DIR = REPO_ROOT / "deploy"


def read_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        values[key.strip()] = value.strip()
    return values


def run_with_password(cmd: list[str], password: str, *, input_data: bytes | None = None) -> tuple[int, bytes]:
    pid, fd = pty.fork()
    if pid == 0:
        os.execvp(cmd[0], cmd)

    output = b""
    password_sent = False
    if input_data:
        os.write(fd, input_data)

    while True:
        ready, _, _ = select.select([fd], [], [], 0.2)
        if fd in ready:
            try:
                chunk = os.read(fd, 4096)
            except OSError:
                break
            if not chunk:
                break
            output += chunk
            sys.stdout.buffer.write(chunk)
            sys.stdout.buffer.flush()
            if not password_sent and b"password:" in output.lower():
                os.write(fd, (password + "\n").encode())
                password_sent = True

        try:
            finished, status = os.waitpid(pid, os.WNOHANG)
            if finished:
                if os.WIFEXITED(status):
                    return os.WEXITSTATUS(status), output
                return 1, output
        except ChildProcessError:
            break

    _, status = os.waitpid(pid, 0)
    return os.WEXITSTATUS(status) if os.WIFEXITED(status) else 1, output


def ssh(host: str, user: str, password: str, remote_command: str) -> int:
    cmd = [
        "ssh",
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "PreferredAuthentications=password,keyboard-interactive",
        "-o", "PubkeyAuthentication=no",
        f"{user}@{host}",
        remote_command,
    ]
    code, _ = run_with_password(cmd, password)
    return code


def scp(host: str, user: str, password: str, local_path: Path, remote_path: str) -> int:
    cmd = [
        "scp",
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "PreferredAuthentications=password,keyboard-interactive",
        "-o", "PubkeyAuthentication=no",
        str(local_path),
        f"{user}@{host}:{remote_path}",
    ]
    code, _ = run_with_password(cmd, password)
    return code


def build_production_env(local_env: dict[str, str], master_key: str) -> str:
    domain = os.environ.get("CREAM_DOMAIN", "crm.example.com")
    db_password = os.environ.get("CREAM_DATABASE_PASSWORD") or local_env.get("CREAM_DATABASE_PASSWORD")
    if not db_password:
        raise SystemExit("Set CREAM_DATABASE_PASSWORD (strong password for production PostgreSQL).")

    lines = [
        f"CREAM_DOMAIN={domain}",
        f"RAILS_MASTER_KEY={master_key}",
        f"CREAM_DATABASE_USER={local_env.get('CREAM_DATABASE_USER', 'cream')}",
        f"CREAM_DATABASE_PASSWORD={db_password}",
        f"GOOGLE_CLIENT_ID={local_env.get('GOOGLE_CLIENT_ID', '')}",
        f"GOOGLE_CLIENT_SECRET={local_env.get('GOOGLE_CLIENT_SECRET', '')}",
        "CREAM_PUBLIC_SIGNUP=false",
        f"CREAM_ORGANIZATION_EMAIL_DOMAIN={local_env.get('CREAM_ORGANIZATION_EMAIL_DOMAIN', 'example.com')}",
        f"CREAM_ORGANIZATION_WORKSPACE_NAME={local_env.get('CREAM_ORGANIZATION_WORKSPACE_NAME', 'Example')}",
        f"CREAM_SEED_ADMIN_EMAIL={local_env.get('CREAM_SEED_ADMIN_EMAIL', '')}",
        f"CREAM_SEED_ADMIN_PASSWORD={local_env.get('CREAM_SEED_ADMIN_PASSWORD', '')}",
        f"CREAM_SEED_MEMBER_EMAIL={local_env.get('CREAM_SEED_MEMBER_EMAIL', '')}",
        f"CREAM_SEED_MEMBER_PASSWORD={local_env.get('CREAM_SEED_MEMBER_PASSWORD', '')}",
        f"RAILS_LOG_LEVEL={local_env.get('RAILS_LOG_LEVEL', 'info')}",
    ]
    return "\n".join(lines) + "\n"


def upload_source_and_build(host: str, user: str, password: str, remote_dir: str) -> int:
    import tarfile

    tarball = Path(tempfile.mkdtemp()) / "cream-src.tgz"
    excludes = {".git", "tmp", "log", "storage", "node_modules", ".bundle"}
    skip_names = {".env", ".env.local", ".env.production", "cream-backup.json"}

    with tarfile.open(tarball, "w:gz") as archive:
        for path in REPO_ROOT.rglob("*"):
            rel = path.relative_to(REPO_ROOT)
            if any(part in excludes for part in rel.parts):
                continue
            if path.name in skip_names or path.name.startswith(".env"):
                continue
            if path.is_file():
                archive.add(path, arcname=rel)

    if scp(host, user, password, tarball, "/tmp/cream-src.tgz") != 0:
        return 1

    build = f"""
set -euo pipefail
rm -rf {remote_dir}-src
mkdir -p {remote_dir}-src
tar xzf /tmp/cream-src.tgz -C {remote_dir}-src
rm -f /tmp/cream-src.tgz
cd {remote_dir}-src
docker build -t ghcr.io/entaina/cream:latest .
"""
    return ssh(host, user, password, build)


def main() -> int:
    host = os.environ.get("CREAM_SERVER_HOST")
    user = os.environ.get("CREAM_SERVER_USER", "deploy")
    remote_dir = os.environ.get("CREAM_REMOTE_DIR", "/home/deploy/cream")
    password = os.environ.get("CREAM_SERVER_PASSWORD")
    build_on_server = os.environ.get("CREAM_BUILD_ON_SERVER", "auto")

    if not host:
        print("Set CREAM_SERVER_HOST to the server IP or hostname.", file=sys.stderr)
        return 1
    if not password:
        print("Set CREAM_SERVER_PASSWORD to the SSH password.", file=sys.stderr)
        return 1

    master_key_path = REPO_ROOT / "config" / "master.key"
    if not master_key_path.exists():
        print(f"Missing {master_key_path}", file=sys.stderr)
        return 1

    master_key = master_key_path.read_text().strip()
    local_env = read_env_file(REPO_ROOT / ".env")
    production_env = build_production_env(local_env, master_key)

    setup = f"""
set -euo pipefail
mkdir -p {remote_dir}
chmod 700 {remote_dir}
docker network inspect proxy >/dev/null 2>&1 || docker network create proxy
"""

    if ssh(host, user, password, setup) != 0:
        return 1

    for filename in ("docker-compose.yml", ".env.production.example"):
        local_file = DEPLOY_DIR / filename
        if scp(host, user, password, local_file, f"{remote_dir}/{filename}") != 0:
            return 1

    with tempfile.NamedTemporaryFile("w", delete=False) as tmp:
        tmp.write(production_env)
        tmp_path = Path(tmp.name)

    try:
        if scp(host, user, password, tmp_path, f"{remote_dir}/.env") != 0:
            return 1
    finally:
        tmp_path.unlink(missing_ok=True)

    pull = f"""
set -euo pipefail
cd {remote_dir}
chmod 600 .env
docker compose pull web 2>/tmp/cream-pull.err || true
if grep -qi denied /tmp/cream-pull.err 2>/dev/null; then
  echo "GHCR pull denied or unavailable"
  exit 42
fi
"""
    pull_code = ssh(host, user, password, pull)

    if pull_code == 42 or build_on_server == "1":
        print("Building image on server from local source...", file=sys.stderr)
        if upload_source_and_build(host, user, password, remote_dir) != 0:
            return 1
    elif pull_code != 0:
        return pull_code

    finalize = f"""
set -euo pipefail
cd {remote_dir}
docker compose pull db || true
docker compose up -d
sleep 15
docker compose ps
curl -sf -o /dev/null -w 'health:%{{http_code}}\\n' http://127.0.0.1/up || docker compose logs --tail=30 web
"""
    return ssh(host, user, password, finalize)


if __name__ == "__main__":
    raise SystemExit(main())
