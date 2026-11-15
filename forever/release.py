#!/usr/bin/env python3
"""Publish the Leatrix Maps+ release for the current commit, unless it's already released.

Runs in the mirror workflow after the mirror action. Leatrix Maps+ is the mirrored Leatrix Maps
built with forever/ (forever/build.py). Releases are tagged <Leatrix Maps version>-plus.<n>:
n starts at 1 for each Leatrix Maps version and goes up whenever the build's inputs change
(the mirrored folder or forever/'s files; their digest is kept in the release notes).

Each release is marked latest, over the mirror action's release of the original zip, so an
addon manager that installs the latest release (Knapsack, WowUp) gets Leatrix Maps+. Its one zip
ends in -forever, the marker Knapsack picks the Forever client's zip by.

usage: python3 forever/release.py [--dry-run]
Needs gh with a token that can create releases (GH_TOKEN in the workflow).
"""
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build  # noqa: E402

INPUTS_MARKER = re.compile(r"<!-- leatrix-maps-plus-inputs: ([0-9a-f]{64}) -->")


def run(*args: str) -> str:
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"release: {' '.join(args[:3])} failed:\n{result.stderr.strip()}")
    return result.stdout


def repository() -> str:
    return os.environ.get("GITHUB_REPOSITORY") or run("gh", "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner").strip()


def inputs_digest() -> str:
    """SHA-256 of everything a build is made from."""
    paths = sorted(p for p in build.SOURCE.rglob("*") if p.is_file())
    paths += [build.HERE / name for name in build.FILES] + [build.HERE / "build.py", build.patch.PATCH]
    paths = [p for p in paths if p.exists()]
    digest = hashlib.sha256()
    for path in paths:
        digest.update(path.relative_to(build.ROOT).as_posix().encode() + b"\0")
        digest.update(path.read_bytes() + b"\0")
    return digest.hexdigest()


def plus_releases(repo: str, upstream: str) -> dict[int, str]:
    """This Leatrix Maps version's Leatrix Maps+ releases: n -> release notes."""
    output = run(
        "gh", "api", "--paginate", f"repos/{repo}/releases?per_page=100",
        "--jq", '.[] | {tag: .tag_name, body: (.body // "")}',
    )
    pattern = re.compile(re.escape(upstream) + r"-plus\.(\d+)$")
    found = {}
    for line in output.splitlines():
        if line.strip():
            release = json.loads(line)
            if match := pattern.match(release["tag"]):
                found[int(match.group(1))] = release["body"]
    return found


def newest_plus(repo: str) -> str | None:
    """The newest Leatrix Maps+ release of any Leatrix Maps version."""
    output = run(
        "gh", "api", "--paginate", f"repos/{repo}/releases?per_page=100",
        "--jq", '.[] | select(.tag_name | test("-plus[.][0-9]+$")) | "\\(.created_at) \\(.tag_name)"',
    )
    tags = sorted(line.split(" ", 1) for line in output.splitlines() if line.strip())
    return tags[-1][1] if tags else None


def interface(folder: Path) -> int:
    text = (folder / "Leatrix_Maps.toc").read_text(encoding="utf-8")
    match = re.search(r"^##\s*Interface:\s*([\d,\s]+)", text, re.MULTILINE)
    if not match:
        sys.exit("release: Leatrix_Maps.toc has no interface")
    return max(int(n) for n in re.findall(r"\d+", match.group(1)))


def write_zip(folder: Path, zip_path: Path) -> None:
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(folder.rglob("*")):
            if path.is_file():
                archive.write(path, f"{folder.name}/{path.relative_to(folder).as_posix()}")


def main() -> None:
    dry_run = "--dry-run" in sys.argv[1:]
    repo = repository()
    upstream = build.upstream_version()
    digest = inputs_digest()

    found = plus_releases(repo, upstream)
    for n, notes in sorted(found.items()):
        if digest in INPUTS_MARKER.findall(notes):
            print(f"Leatrix Maps+ {upstream}-plus.{n} is this build; nothing to release")
            return
    n = max(found, default=0) + 1
    version = f"{upstream}-plus.{n}"
    commit = run("git", "rev-parse", "HEAD").strip()

    with tempfile.TemporaryDirectory(prefix="leatrix-maps-plus-") as temp:
        temp = Path(temp)
        try:
            folder = build.build(temp / "build", f"plus.{n}")
        except SystemExit:
            # The patch conflicts with this Leatrix Maps: until it's fixed, keep players on the
            # last Leatrix Maps+ rather than the original zip the mirror action just made latest
            last = newest_plus(repo)
            if last and not dry_run:
                run("gh", "release", "edit", last, "--repo", repo, "--latest")
                print(f"release: kept {last} as the latest release", file=sys.stderr)
            raise
        zip_name = f"Leatrix_Maps-{version}-forever.zip"
        zip_path = temp / zip_name
        write_zip(folder, zip_path)

        # The mirror action's release.json, for managers that read one (WowUp)
        release_json = temp / "release.json"
        release_json.write_text(json.dumps({"releases": [{
            "name": "Leatrix Maps",
            "version": version,
            "filename": zip_name,
            "nolib": False,
            "metadata": [{"flavor": "classic", "interface": interface(folder)}],
        }]}, indent=2) + "\n")

        notes = "\n".join([
            f"Leatrix Maps+: Leatrix Maps {upstream} with this repository's WoW Forever additions"
            " (see [forever/](../../tree/main/forever)). Unofficial; report problems here, not to Leatrix.",
            "",
            f"Built from {commit[:12]}.",
            "",
            f"<!-- leatrix-maps-plus-inputs: {digest} -->",
        ])

        if dry_run:
            print(f"[dry-run] would release {version} at {commit[:12]} with {zip_name} "
                  f"({zip_path.stat().st_size} bytes) and release.json")
            print(release_json.read_text())
            return
        run(
            "gh", "release", "create", version, str(zip_path), str(release_json),
            "--repo", repo, "--target", commit, "--title", f"Leatrix Maps+ {version}",
            "--notes", notes, "--latest",
        )
        print(f"released Leatrix Maps+ {version}")


if __name__ == "__main__":
    main()
