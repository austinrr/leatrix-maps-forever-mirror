#!/usr/bin/env python3
"""Leatrix Maps+'s changes to Leatrix Maps' own code, kept as one patch: forever/leatrix.patch.

Leatrix_Maps/ always holds Leatrix Maps exactly as mirrored (the mirror action replaces it with
each upstream version); forever/build.py applies the patch to a copy when it builds. To change
Leatrix Maps' code, or to fix the patch after an upstream update conflicts with it:

    python3 forever/patch.py apply    # the patch into Leatrix_Maps/ (3-way: conflicts get markers)
    ...edit Leatrix_Maps/, resolving any conflict markers...
    python3 forever/patch.py save     # Leatrix_Maps/'s changes -> forever/leatrix.patch
    python3 forever/patch.py reset    # Leatrix_Maps/ back as mirrored; commit forever/leatrix.patch

    python3 forever/patch.py check    # does the patch apply to Leatrix_Maps/ as it is?

Conflicts only happen when upstream changes the lines the patch changes (or the line next to
them); the patch applies to anything else upstream does.
"""
import os
import subprocess
import sys
import tempfile
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PATCH = ROOT / "forever" / "leatrix.patch"
FOLDER = "Leatrix_Maps"
CONTEXT = "-C1"	# lines of unchanged context that must match around each change


def git(*args: str, check: bool = True, cwd: Path = ROOT) -> subprocess.CompletedProcess:
    result = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)
    if check and result.returncode != 0:
        sys.exit(f"patch: git {' '.join(args)} failed:\n{result.stderr.strip()}")
    return result


def dirty() -> bool:
    return bool(git("status", "--porcelain", "--", FOLDER).stdout.strip())


def apply_to(folder_parent: Path) -> tuple[bool, str]:
    """Apply the patch to <folder_parent>/Leatrix_Maps, a copy outside any repository."""
    if not PATCH.exists() or PATCH.stat().st_size == 0:
        return True, ""
    # (git mustn't take a repository above the copy for its own: it would patch that instead)
    env = {**os.environ, "GIT_CEILING_DIRECTORIES": str(folder_parent.resolve().parent)}
    result = subprocess.run(["git", "apply", CONTEXT, "--whitespace=nowarn", str(PATCH)],
                            cwd=folder_parent, env=env, capture_output=True, text=True)
    return result.returncode == 0, result.stderr.strip()


def cmd_apply() -> None:
    if dirty():
        sys.exit(f"patch: {FOLDER}/ has changes already; save or reset them first")
    result = git("apply", "--3way", CONTEXT, "--whitespace=nowarn", str(PATCH), check=False)
    if result.returncode == 0:
        print(f"applied {PATCH.name} to {FOLDER}/: edit, then save and reset")
    else:
        print(result.stderr.strip())
        print(f"\n{FOLDER}/ has conflicts: resolve the <<<<<<< markers, then save and reset")
        sys.exit(1)


def cmd_save() -> None:
    conflicted = git("grep", "-l", "-e", "^<<<<<<< ", "-e", "^>>>>>>> ", "--", FOLDER, check=False).stdout.strip()
    if conflicted:
        sys.exit(f"patch: conflict markers left in:\n{conflicted}")
    diff = subprocess.run(["git", "diff", "HEAD", "--full-index", "--binary", "--", FOLDER],
                          cwd=ROOT, capture_output=True, check=True).stdout
    PATCH.write_bytes(diff)
    print(f"saved {len(diff)} bytes to {PATCH.relative_to(ROOT)}" if diff else f"no changes: {PATCH.relative_to(ROOT)} is empty")


def cmd_reset() -> None:
    git("checkout", "HEAD", "--", FOLDER)
    git("clean", "-fdq", "--", FOLDER)
    print(f"{FOLDER}/ is back as mirrored")


def cmd_check() -> None:
    with tempfile.TemporaryDirectory(prefix="leatrix-maps-plus-check-") as temp:
        shutil.copytree(ROOT / FOLDER, Path(temp) / FOLDER)
        ok, error = apply_to(Path(temp))
    if not ok:
        sys.exit(f"patch: {PATCH.name} doesn't apply to {FOLDER}/:\n{error}\n\nFix it with: python3 forever/patch.py apply")
    print(f"{PATCH.name} applies cleanly")


def main() -> None:
    commands = {"apply": cmd_apply, "save": cmd_save, "reset": cmd_reset, "check": cmd_check}
    if len(sys.argv) != 2 or sys.argv[1] not in commands:
        sys.exit(__doc__)
    commands[sys.argv[1]]()


if __name__ == "__main__":
    main()
