#!/usr/bin/env python3
"""Build Leatrix Maps+: the mirrored Leatrix_Maps folder with forever/leatrix.patch applied,
plus the files in forever/.

usage: python3 forever/build.py [out_dir]

Writes <out_dir>/Leatrix_Maps (default out_dir: dist/ at the repository root), replacing any
Leatrix_Maps already there, so out_dir can be the game's Interface/AddOns folder. A local
build's version is <Leatrix Maps version>-plus.dev; forever/release.py numbers releases.

The mirrored folder is never changed: the mirror action replaces it with each CurseForge
release. forever/ has no .toc at its root, so the action leaves it alone.
"""
import re
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import patch  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Leatrix_Maps"
HERE = ROOT / "forever"

# Loaded in this order, right after Leatrix_Maps_Icons.lua (they add to its icon table)
FILES = ["Leatrix_Maps_Forever.lua", "Leatrix_Maps_Editor.lua"]
AFTER = "Leatrix_Maps_Icons.lua"
SAVED_VARIABLES = "LeaMapsForeverDB"
TITLE = "Leatrix Maps+"
NOTES = "Leatrix Maps+: Leatrix Maps with WoW Forever additions (unofficial build): github.com/austinrr/leatrix-maps-forever-mirror"


def patch_toc(text: str, suffix: str) -> str:
    eol = "\r\n" if "\r\n" in text else "\n"
    lines = text.split(eol)

    try:
        at = next(i for i, line in enumerate(lines) if line.strip() == AFTER)
    except StopIteration:
        sys.exit(f"build: {AFTER} isn't in the toc; Leatrix Maps' file list changed, check forever/build.py")
    lines[at + 1:at + 1] = FILES

    seen = set()
    for i, line in enumerate(lines):
        if m := re.match(r"##\s*SavedVariables:\s*(.*)$", line):
            names = [n.strip() for n in m.group(1).split(",") if n.strip()]
            if SAVED_VARIABLES not in names:
                names.append(SAVED_VARIABLES)
            lines[i] = "## SavedVariables: " + ", ".join(names)
            seen.add("saved")
        elif m := re.match(r"##\s*Version:\s*(.*)$", line):
            lines[i] = f"## Version: {m.group(1).strip()}-{suffix}"
            seen.add("version")
        elif re.match(r"##\s*Title:", line):
            lines[i] = f"## Title: {TITLE}"
        elif re.match(r"##\s*Notes:", line):
            lines[i] = f"## Notes: {NOTES}"
            seen.add("notes")
    for key in ("saved", "version"):
        if key not in seen:
            sys.exit(f"build: the toc has no {key} line; check forever/build.py")
    return eol.join(lines)


def upstream_version() -> str:
    """The mirrored Leatrix Maps version (its toc's ## Version)."""
    text = (SOURCE / "Leatrix_Maps.toc").read_text(encoding="utf-8")
    match = re.search(r"^##\s*Version:\s*(\S+)", text, re.MULTILINE)
    if not match:
        sys.exit("build: Leatrix_Maps.toc has no version")
    return match.group(1)


def build(out: Path, suffix: str) -> Path:
    """Write <out>/Leatrix_Maps with version <upstream>-<suffix>; returns the folder.

    Built in a folder of its own outside the repository (forever/leatrix.patch is applied
    there), then copied to <out>; a patch that doesn't apply stops the build."""
    dest = out / "Leatrix_Maps"
    if dest.resolve() == SOURCE.resolve():
        sys.exit("build: refusing to build over the mirrored folder")

    with tempfile.TemporaryDirectory(prefix="leatrix-maps-plus-build-") as temp:
        work = Path(temp) / "Leatrix_Maps"
        shutil.copytree(SOURCE, work)
        ok, error = patch.apply_to(Path(temp))
        if not ok:
            sys.exit(f"build: forever/leatrix.patch doesn't apply to this Leatrix Maps ({upstream_version()}):\n"
                     f"{error}\n\nUpstream changed lines the patch changes. Fix it with: python3 forever/patch.py apply")
        for name in FILES:
            shutil.copy2(HERE / name, work / name)

        toc = work / "Leatrix_Maps.toc"
        with open(toc, encoding="utf-8", newline="") as f:
            text = f.read()
        with open(toc, "w", encoding="utf-8", newline="") as f:
            f.write(patch_toc(text, suffix))

        if dest.exists():
            shutil.rmtree(dest)
        out.mkdir(parents=True, exist_ok=True)
        shutil.copytree(work, dest)
    return dest


def main() -> None:
    out = Path(sys.argv[1]).expanduser() if len(sys.argv) > 1 else ROOT / "dist"
    dest = build(out, "plus.dev")
    print(f"built Leatrix Maps+ {upstream_version()}-plus.dev in {dest}")


if __name__ == "__main__":
    main()
