#!/usr/bin/env python3
"""Resolve latest official MySQL 8.4 LTS Debian 13 package, gosu release, and Go toolchain."""

from __future__ import annotations

import json
import os
import re
import urllib.error
import urllib.request
from pathlib import Path


def fetch_text(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "dgcosenza-mysql-docker-ci"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read().decode("utf-8", errors="replace")


def fetch_json(url: str, github_api: bool = False):
    headers = {"User-Agent": "dgcosenza-mysql-docker-ci"}
    if github_api:
        headers["Accept"] = "application/vnd.github+json"
        headers["X-GitHub-Api-Version"] = "2022-11-28"
        token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
        if token:
            headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def url_ok(url: str) -> bool:
    req = urllib.request.Request(url, method="HEAD", headers={"User-Agent": "dgcosenza-mysql-docker-ci"})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return 200 <= resp.status < 400
    except urllib.error.HTTPError as exc:
        if exc.code == 405:
            req_get = urllib.request.Request(url, headers={"User-Agent": "dgcosenza-mysql-docker-ci"})
            try:
                with urllib.request.urlopen(req_get, timeout=20) as resp2:
                    return 200 <= resp2.status < 400
            except Exception:
                return False
        return False
    except Exception:
        return False


def ver_tuple(v: str) -> tuple[int, ...]:
    return tuple(int(x) for x in re.findall(r"\d+", v.split("-")[0]))


def resolve_mysql(major: str, override: str) -> tuple[str, str, str]:
    if override:
        upstream = ".".join(override.split("-")[0].split(".")[:3])
        return override, upstream, f"Manual override requested: MySQL {override}."

    pkg_index = fetch_text(f"https://repo.mysql.com/apt/debian/dists/trixie/mysql-{major}-lts/binary-amd64/Packages")
    versions: list[str] = []
    cur_pkg = ""
    for line in pkg_index.splitlines():
        if line.startswith("Package: "):
            cur_pkg = line.split(": ", 1)[1].strip()
        elif line.startswith("Version: ") and cur_pkg == "mysql-community-server":
            versions.append(line.split(": ", 1)[1].strip())

    if not versions:
        raise SystemExit(f"ERROR: No mysql-community-server packages found for Debian 13 (mysql-{major}-lts)")

    versions.sort(key=ver_tuple, reverse=True)
    deb_ver = versions[0]
    upstream_ver = ".".join(deb_ver.split("-")[0].split(".")[:3])
    notes_url = f"https://dev.mysql.com/doc/relnotes/mysql/{major}/en/news-{upstream_ver.replace('.', '-')}.html"
    notes = f"Official Oracle MySQL {upstream_ver} LTS Debian 13 package (`{deb_ver}`). Release notes: {notes_url}"
    return deb_ver, upstream_ver, notes


def resolve_gosu(override: str, default_ver: str) -> str:
    if override:
        return override
    try:
        rel = fetch_json("https://api.github.com/repos/tianon/gosu/releases/latest", github_api=True)
        tag = (rel.get("tag_name") or "").strip()
        if tag:
            return tag
    except Exception:
        pass
    return default_ver


def resolve_go(override: str, default_ver: str) -> str:
    if override:
        return override
    try:
        releases = fetch_json("https://go.dev/dl/?mode=json")
        for rel in releases:
            if not rel.get("stable"):
                continue
            ver = rel.get("version", "").removeprefix("go")
            if not re.fullmatch(r"\d+\.\d+(\.\d+)?", ver):
                continue
            if url_ok(f"https://hub.docker.com/v2/repositories/library/golang/tags/{ver}-trixie"):
                return ver
    except Exception:
        pass
    return default_ver


def main() -> None:
    major = os.environ.get("MYSQL_MAJOR", "8.4")
    deb_ver, upstream_ver, notes = resolve_mysql(major, os.environ.get("OVERRIDE_MYSQL", "").strip())
    gosu_ver = resolve_gosu(os.environ.get("OVERRIDE_GOSU", "").strip(), os.environ.get("GOSU_VERSION_DEFAULT", "1.20"))
    go_ver = resolve_go(os.environ.get("OVERRIDE_GO", "").strip(), os.environ.get("GO_VERSION_DEFAULT", "1.27.4"))

    prev = {}
    vpath = Path("versions.json")
    if vpath.exists():
        prev = json.loads(vpath.read_text(encoding="utf-8"))
    prev_mysql = prev.get("mysql_version", "")
    prev_deb = prev.get("mysql_deb_version", "")
    prev_go = prev.get("go_version", "")
    prev_gosu = prev.get("gosu_version", "")

    changed = (deb_ver != prev_deb) or (go_ver != prev_go) or (gosu_ver != prev_gosu)
    md = [
        f"# Upstream changes — MySQL {major} LTS",
        "",
        f"- **MySQL {major}:** `{prev_mysql or 'none'}` (`{prev_deb or 'none'}`) -> `{upstream_ver}` (`{deb_ver}`)",
        f"- **gosu:** `{prev_gosu or 'none'}` -> `{gosu_ver}`",
        f"- **Go toolchain (gosu builder):** `{prev_go or 'none'}` -> `{go_ver}`",
        f"- **Upstream version changed:** `{'yes' if changed else 'no'}`",
        "",
        "## Release notes",
        "",
        notes,
        "",
    ]
    Path("upstream-changes.md").write_text("\n".join(md), encoding="utf-8")

    outputs = {
        "mysql_major": major,
        "mysql_version": upstream_ver,
        "mysql_deb_version": deb_ver,
        "prev_mysql_version": prev_mysql,
        "gosu_version": gosu_ver,
        "go_version": go_ver,
        "upstream_changed": "true" if changed else "false",
    }
    gh_out = os.environ.get("GITHUB_OUTPUT")
    if gh_out:
        with open(gh_out, "a", encoding="utf-8") as fh:
            for k, v in outputs.items():
                fh.write(f"{k}={v}\n")
    for k, v in outputs.items():
        print(f"{k}={v}")


if __name__ == "__main__":
    main()
