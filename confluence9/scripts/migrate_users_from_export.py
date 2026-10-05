#!/usr/bin/env python3
"""Migrate Confluence internal users/groups from export files into local DB.

Password for every user (including admin update): 123456
PKCS5S2 = PBKDF2-HMAC-SHA1, 10000 iters, 16-byte salt + 32-byte key.
"""

from __future__ import annotations

import base64
import os
import secrets
import subprocess
import sys
from datetime import datetime, timezone
from hashlib import pbkdf2_hmac
from pathlib import Path

PASSWORD = "123456"
DIR_ID = None  # filled from DB
ROOT = Path(__file__).resolve().parent
USERS_FILE = Path(os.environ.get("USERS_FILE", "/tmp/old_users.txt"))
GROUPS_FILE = Path(os.environ.get("GROUPS_FILE", "/tmp/old_groups.txt"))
MEMBERS_FILE = Path(os.environ.get("MEMBERS_FILE", "/tmp/old_members.txt"))


def pkcs5s2(password: str) -> str:
    salt = secrets.token_bytes(16)
    key = pbkdf2_hmac("sha1", password.encode(), salt, 10000, dklen=32)
    return "{PKCS5S2}" + base64.b64encode(salt + key).decode()


def sql_str(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def psql(sql: str) -> str:
    cmd = [
        "sudo",
        "docker",
        "exec",
        "-i",
        "wiki-pgsql",
        "psql",
        "-U",
        "confluence",
        "-d",
        "confluence",
        "-v",
        "ON_ERROR_STOP=1",
        "-t",
        "-A",
    ]
    r = subprocess.run(cmd, input=sql, text=True, capture_output=True)
    if r.returncode != 0:
        raise SystemExit(f"psql failed:\n{r.stderr}\n{r.stdout}\nSQL:\n{sql[:500]}")
    return r.stdout.strip()


def load_pipe(path: Path) -> list[list[str]]:
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        rows.append(line.split("|"))
    return rows


def main() -> int:
    users = load_pipe(USERS_FILE)
    groups = load_pipe(GROUPS_FILE)
    members = load_pipe(MEMBERS_FILE)
    print(f"[info] users={len(users)} groups={len(groups)} members={len(members)}")

    dir_id = psql("select id from cwd_directory where directory_type='INTERNAL' limit 1;")
    if not dir_id:
        raise SystemExit("no INTERNAL directory")
    print(f"[info] directory_id={dir_id}")

    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    cred = pkcs5s2(PASSWORD)

    # Ensure custom groups exist (skip built-ins that already exist)
    existing_groups = {
        g.lower()
        for g in psql("select lower_group_name from cwd_group;").splitlines()
        if g
    }
    gid = int(psql("select coalesce(max(id),0) from cwd_group;") or "0")
    group_ids: dict[str, int] = {}
    # map existing
    for line in psql("select id||'|'||lower_group_name from cwd_group;").splitlines():
        if not line:
            continue
        i, n = line.split("|", 1)
        group_ids[n] = int(i)

    stmts: list[str] = ["BEGIN;"]
    for gname, active in groups:
        low = gname.lower()
        if low in group_ids:
            continue
        gid += 1
        group_ids[low] = gid
        stmts.append(
            "INSERT INTO cwd_group "
            "(id, group_name, lower_group_name, active, local, created_date, updated_date, "
            "description, group_type, directory_id, external_id) VALUES ("
            f"{gid}, {sql_str(gname)}, {sql_str(low)}, {sql_str(active or 'T')}, 'T', "
            f"TIMESTAMP {sql_str(now)}, TIMESTAMP {sql_str(now)}, NULL, 'GROUP', {dir_id}, NULL);"
        )
        print(f"[+] group {gname} id={gid}")

    # Users
    existing_users = {
        u.lower()
        for u in psql("select lower_user_name from cwd_user;").splitlines()
        if u
    }
    uid = int(psql("select coalesce(max(id),0) from cwd_user;") or "0")
    user_ids: dict[str, int] = {}
    for line in psql("select id||'|'||lower_user_name from cwd_user;").splitlines():
        if not line:
            continue
        i, n = line.split("|", 1)
        user_ids[n] = int(i)

    for row in users:
        # user_name|email|display|active|first|last
        while len(row) < 6:
            row.append("")
        uname, email, display, active, first, last = row[:6]
        low = uname.lower()
        email = email or f"{low}@911g.net"
        display = display or uname
        first = first or ""
        last = last or uname
        active = active or "T"
        # unique salt/hash per user
        ucred = pkcs5s2(PASSWORD)
        if low in existing_users:
            stmts.append(
                "UPDATE cwd_user SET "
                f"credential={sql_str(ucred)}, "
                f"email_address={sql_str(email)}, "
                f"lower_email_address={sql_str(email.lower())}, "
                f"display_name={sql_str(display)}, "
                f"lower_display_name={sql_str(display.lower())}, "
                f"first_name={sql_str(first)}, "
                f"lower_first_name={sql_str(first.lower())}, "
                f"last_name={sql_str(last)}, "
                f"lower_last_name={sql_str(last.lower())}, "
                f"active={sql_str(active)}, "
                f"updated_date=TIMESTAMP {sql_str(now)} "
                f"WHERE lower_user_name={sql_str(low)} AND directory_id={dir_id};"
            )
            print(f"[~] user {uname} (update password)")
            continue
        uid += 1
        user_ids[low] = uid
        stmts.append(
            "INSERT INTO cwd_user "
            "(id, user_name, lower_user_name, active, created_date, updated_date, "
            "first_name, lower_first_name, last_name, lower_last_name, "
            "display_name, lower_display_name, email_address, lower_email_address, "
            "external_id, directory_id, credential) VALUES ("
            f"{uid}, {sql_str(uname)}, {sql_str(low)}, {sql_str(active)}, "
            f"TIMESTAMP {sql_str(now)}, TIMESTAMP {sql_str(now)}, "
            f"{sql_str(first)}, {sql_str(first.lower())}, "
            f"{sql_str(last)}, {sql_str(last.lower())}, "
            f"{sql_str(display)}, {sql_str(display.lower())}, "
            f"{sql_str(email)}, {sql_str(email.lower())}, "
            f"NULL, {dir_id}, {sql_str(ucred)});"
        )
        print(f"[+] user {uname} id={uid}")

    # refresh maps after planned inserts — for membership use final maps
    # Memberships
    mid = int(psql("select coalesce(max(id),0) from cwd_membership;") or "0")
    existing_mem = set()
    for line in psql(
        "select g.lower_group_name||'|'||u.lower_user_name "
        "from cwd_membership m "
        "join cwd_group g on g.id=m.parent_id "
        "join cwd_user u on u.id=m.child_user_id;"
    ).splitlines():
        if line:
            existing_mem.add(line)

    # rebuild user_ids/group_ids including ones we will insert
    # (already tracked in dicts above)

    for gname, uname in members:
        glow, ulow = gname.lower(), uname.lower()
        key = f"{glow}|{ulow}"
        if key in existing_mem:
            continue
        if glow not in group_ids:
            print(f"[skip] missing group {gname}", file=sys.stderr)
            continue
        if ulow not in user_ids:
            print(f"[skip] missing user {uname}", file=sys.stderr)
            continue
        mid += 1
        stmts.append(
            "INSERT INTO cwd_membership (id, parent_id, child_group_id, child_user_id) VALUES ("
            f"{mid}, {group_ids[glow]}, NULL, {user_ids[ulow]});"
        )
        existing_mem.add(key)
        print(f"[+] member {gname} <- {uname}")

    # bump hibernate hi so future IDs stay clear of our range
    stmts.append("UPDATE hibernate_unique_key SET next_hi = GREATEST(next_hi, 40);")
    stmts.append("COMMIT;")

    sql = "\n".join(stmts) + "\n"
    Path("/tmp/migrate_users.sql").write_text(sql, encoding="utf-8")
    print(f"[info] wrote /tmp/migrate_users.sql ({len(stmts)} statements)")
    psql(sql)
    print("[ok] applied")

    # verify
    print(
        "[verify]",
        psql(
            "select count(*)||' users, '||"
            "(select count(*) from cwd_group)||' groups, '||"
            "(select count(*) from cwd_membership)||' memberships' from cwd_user;"
        ),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
