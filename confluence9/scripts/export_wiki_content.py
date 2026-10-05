#!/usr/bin/env python3
"""Export current pages and attachments from the old Confluence DB + home."""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

OUT = Path("/tmp/wiki-export")
HOME = Path("/opt/confluence/data/confluence/attachments")


def psql_json(sql: str, dest: Path) -> None:
    cmd = [
        "sudo", "docker", "exec", "-i", "confluence-pgsql",
        "psql", "-U", "confluence", "-d", "confluence",
        "-v", "ON_ERROR_STOP=1", "-t", "-A",
    ]
    r = subprocess.run(cmd, input=sql + "\n", text=True, capture_output=True)
    if r.returncode != 0:
        raise SystemExit(r.stderr or r.stdout)
    dest.write_text(r.stdout.strip(), encoding="utf-8")


def main() -> None:
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir()
    (OUT / "files").mkdir()

    psql_json(
        """
        SELECT coalesce(json_agg(q), '[]'::json)::text FROM (
          SELECT s.spacekey, s.spacename, h.title AS homepage
          FROM spaces s
          JOIN content h ON h.contentid = s.homepage
          ORDER BY s.spacekey
        ) q
        """,
        OUT / "spaces.json",
    )
    psql_json(
        """
        SELECT coalesce(json_agg(q), '[]'::json)::text FROM (
          SELECT c.contentid::text AS id,
                 s.spacekey,
                 c.title,
                 CASE WHEN c.parentid IS NULL THEN NULL ELSE c.parentid::text END AS parent_id,
                 coalesce(c.child_position, 0) AS pos,
                 coalesce((
                   SELECT bc.body FROM bodycontent bc
                   WHERE bc.contentid = c.contentid
                   ORDER BY bc.bodycontentid DESC LIMIT 1
                 ), '') AS body
          FROM content c
          JOIN spaces s ON s.spaceid = c.spaceid
          WHERE c.prevver IS NULL
            AND c.content_status = 'current'
            AND c.contenttype = 'PAGE'
          ORDER BY s.spacekey, c.child_position, c.contentid
        ) q
        """,
        OUT / "pages.json",
    )
    psql_json(
        """
        SELECT coalesce(json_agg(q), '[]'::json)::text FROM (
          SELECT c.contentid::text AS id,
                 c.title,
                 c.version,
                 c.pageid::text AS page_id
          FROM content c
          WHERE c.prevver IS NULL
            AND c.content_status = 'current'
            AND c.contenttype = 'ATTACHMENT'
          ORDER BY c.pageid, c.contentid
        ) q
        """,
        OUT / "attachments.json",
    )

    def load_agg(path: Path):
        data = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(data, str):
            data = json.loads(data)
        return data

    spaces = load_agg(OUT / "spaces.json")
    pages = load_agg(OUT / "pages.json")
    attachments = load_agg(OUT / "attachments.json")
    (OUT / "spaces.json").write_text(json.dumps(spaces, ensure_ascii=False), encoding="utf-8")
    (OUT / "pages.json").write_text(json.dumps(pages, ensure_ascii=False), encoding="utf-8")

    missing = []
    for att in attachments:
        aid = att["id"]
        ver = att["version"]
        matches = list(HOME.glob(f"**/{aid}/{aid}.{ver}"))
        if not matches:
            matches = list(HOME.glob(f"**/{aid}/{aid}.*"))
        if not matches:
            missing.append(aid)
            continue
        src = matches[-1]
        dest = OUT / "files" / f"{aid}--{att['title'].replace('/', '_')}"
        shutil.copy2(src, dest)
        att["file"] = dest.name
    (OUT / "attachments.json").write_text(json.dumps(attachments, ensure_ascii=False), encoding="utf-8")
    print(f"spaces={len(spaces)} pages={len(pages)} attachments={len(attachments)} missing_files={len(missing)}")
    if missing:
        print("missing", ",".join(missing[:20]))


if __name__ == "__main__":
    main()
