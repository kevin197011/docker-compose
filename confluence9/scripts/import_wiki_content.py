#!/usr/bin/env python3
"""Copy exported pages and attachments into Confluence 9 over REST. Does not change version."""

from __future__ import annotations

import json
import os
import ssl
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

BASE = os.environ.get("CONFLUENCE_BASE", "https://confluence.qj-devops.com").rstrip("/")
USER = os.environ.get("CONFLUENCE_USER", "admin")
PASSWORD = os.environ.get("CONFLUENCE_PASSWORD", "123456")
EXPORT = Path(os.environ.get("WIKI_EXPORT", "/tmp/wiki-export"))
CTX = ssl.create_default_context()


def request(method: str, path: str, payload: dict | None = None, raw: bytes | None = None, headers: dict | None = None) -> tuple[int, bytes]:
    url = path if path.startswith("http") else BASE + path
    data = raw if raw is not None else (None if payload is None else json.dumps(payload).encode())
    hdr = {"Authorization": "Basic " + __import__("base64").b64encode(f"{USER}:{PASSWORD}".encode()).decode()}
    if payload is not None:
        hdr["Content-Type"] = "application/json"
    if headers:
        hdr.update(headers)
    last = None
    for attempt in range(5):
        req = urllib.request.Request(url, data=data, headers=hdr, method=method)
        try:
            with urllib.request.urlopen(req, context=CTX, timeout=120) as resp:
                return resp.status, resp.read()
        except urllib.error.HTTPError as e:
            body = e.read()
            if e.code in (429, 502, 503, 504) and attempt < 4:
                time.sleep(2 + attempt * 2)
                last = (e.code, body)
                continue
            return e.code, body
    return last or (0, b"")


def api_json(method: str, path: str, payload: dict | None = None) -> dict:
    code, body = request(method, path, payload=payload)
    text = body.decode(errors="replace")
    if code >= 300:
        raise RuntimeError(f"{method} {path} -> {code} {text[:500]}")
    if not text:
        return {}
    return json.loads(text)


def list_pages(space: str) -> dict[str, str]:
    found: dict[str, str] = {}
    start = 0
    while True:
        data = api_json(
            "GET",
            f"/rest/api/content?spaceKey={urllib.parse.quote(space)}&type=page&limit=100&start={start}",
        )
        for item in data.get("results", []):
            found[item["title"]] = item["id"]
        if data.get("size", 0) < 100:
            break
        start += 100
    return found


def list_attachment_names(page_id: str) -> set[str]:
    data = api_json("GET", f"/rest/api/content/{page_id}/child/attachment?limit=200")
    return {item["title"] for item in data.get("results", [])}


def put_body(page_id: str, page: dict, body: dict) -> str:
    current = api_json("GET", f"/rest/api/content/{page_id}?expand=version,body.storage")
    old = ((current.get("body") or {}).get("storage") or {}).get("value") or ""
    new = body["storage"]["value"]
    if old.strip() == (new or "").strip():
        return "same"
    api_json(
        "PUT",
        f"/rest/api/content/{page_id}",
        {
            "id": page_id,
            "type": "page",
            "title": page["title"],
            "space": {"key": page["spacekey"]},
            "version": {"number": current["version"]["number"] + 1},
            "body": body,
        },
    )
    return "updated"


def upload(page_id: str, filename: str, blob: bytes) -> None:
    boundary = uuid.uuid4().hex
    head = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'
        f"Content-Type: application/octet-stream\r\n\r\n"
    ).encode()
    raw = head + blob + f"\r\n--{boundary}--\r\n".encode()
    code, body = request(
        "POST",
        f"/rest/api/content/{page_id}/child/attachment",
        raw=raw,
        headers={
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "X-Atlassian-Token": "nocheck",
        },
    )
    if code >= 300:
        raise RuntimeError(f"upload {filename} -> {code} {body.decode(errors='replace')[:400]}")


def main() -> None:
    spaces = json.loads((EXPORT / "spaces.json").read_text(encoding="utf-8"))
    pages = json.loads((EXPORT / "pages.json").read_text(encoding="utf-8"))
    attachments = json.loads((EXPORT / "attachments.json").read_text(encoding="utf-8"))
    existing_spaces = {
        s["key"]: s for s in api_json("GET", "/rest/api/space?limit=50").get("results", [])
    }
    for space in spaces:
        key = space["spacekey"]
        if key in existing_spaces:
            print(f"[space] {key} exists")
            continue
        api_json("POST", "/rest/api/space", {"key": key, "name": space["spacename"]})
        print(f"[space] created {key}")
        existing_spaces[key] = {"key": key}

    by_id = {p["id"]: p for p in pages}
    title_to_new: dict[tuple[str, str], str] = {}
    for space in spaces:
        title_to_new.update({(space["spacekey"], t): i for t, i in list_pages(space["spacekey"]).items()})

    pending = list(pages)
    created = 0
    while pending:
        progressed = False
        still = []
        for page in pending:
            parent_id = page.get("parent_id")
            parent = by_id.get(parent_id) if parent_id else None
            if parent and (parent["spacekey"], parent["title"]) not in title_to_new:
                still.append(page)
                continue
            key = (page["spacekey"], page["title"])
            body = {
                "storage": {
                    "value": page.get("body") or "<p></p>",
                    "representation": "storage",
                }
            }
            if key in title_to_new:
                try:
                    state = put_body(title_to_new[key], page, body)
                except RuntimeError as exc:
                    print(f"[page] FAIL update {page['spacekey']} / {page['title']}: {exc}")
                    state = "fail"
                if state == "updated":
                    print(f"[page] updated {page['spacekey']} / {page['title']}")
                progressed = True
                continue
            payload = {
                "type": "page",
                "title": page["title"],
                "space": {"key": page["spacekey"]},
                "body": body,
            }
            if parent:
                payload["ancestors"] = [{"id": title_to_new[(parent["spacekey"], parent["title"])]}]
            try:
                made = api_json("POST", "/rest/api/content", payload)
            except RuntimeError as exc:
                # Homepage title often already exists after space creation.
                if "A page with this title already exists" in str(exc) or "already exists" in str(exc):
                    title_to_new.update(
                        {(page["spacekey"], t): i for t, i in list_pages(page["spacekey"]).items()}
                    )
                    if key in title_to_new:
                        # fill the existing page body
                        state = put_body(title_to_new[key], page, body)
                        if state == "updated":
                            print(f"[page] updated {page['spacekey']} / {page['title']}")
                        progressed = True
                        continue
                print(f"[page] FAIL {page['spacekey']} / {page['title']}: {exc}")
                progressed = True
                continue
            title_to_new[key] = made["id"]
            created += 1
            print(f"[page] {page['spacekey']} / {page['title']}")
            progressed = True
        if not progressed:
            for page in still:
                print(f"[page] stuck parent {page['spacekey']} / {page['title']}")
            break
        pending = still

    page_new = {p["id"]: title_to_new.get((p["spacekey"], p["title"])) for p in pages}
    uploaded = 0
    known: dict[str, set[str]] = {}
    for att in attachments:
        new_page = page_new.get(att["page_id"])
        if not new_page or not att.get("file"):
            print(f"[file] skip {att['title']} (no page or file)")
            continue
        names = known.setdefault(new_page, list_attachment_names(new_page))
        if att["title"] in names:
            continue
        try:
            blob = (EXPORT / "files" / att["file"]).read_bytes()
            upload(new_page, att["title"], blob)
        except (OSError, RuntimeError) as exc:
            print(f"[file] FAIL {att['title']}: {exc}")
            continue
        names.add(att["title"])
        uploaded += 1
        print(f"[file] {att['title']}")
    print(f"[done] created_or_walked pages, uploaded={uploaded}")


if __name__ == "__main__":
    main()
