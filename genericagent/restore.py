#!/usr/bin/env python3
"""Restore Personal GA Configuration to GenericAgent.

Usage:
    python restore.py /path/to/GenericAgent          # explicit path
    python restore.py                                  # auto-detect (parent dir)
    GA_AGENT_DIR=/path/to/GA python restore.py         # env var

This script copies your personalized memory files, skills, and configs
into the GenericAgent installation. Existing upstream files are preserved
unless you explicitly overwrite them.

Safety:
    - No files are deleted
    - Existing files are backed up with .bak extension
    - Sensitive configs (mykey.py) are skipped if not found in templates/
"""

import os
import sys
import shutil
from pathlib import Path


def detect_agent_root(candidate=None):
    """Detect GenericAgent root directory."""
    if candidate:
        return Path(candidate)

    # Check parent of current working directory
    cwd = Path.cwd()
    for parent in [cwd, cwd.parent, cwd.parent.parent]:
        if (parent / "ga.py").exists():
            return parent

    # Check environment variable
    env = os.environ.get("GA_AGENT_DIR")
    if env:
        return Path(env)

    return None


def copy_if_changed(src, dst):
    """Copy file only if different. Returns True if copied."""
    dst = Path(dst)
    if dst.exists():
        try:
            if src.read_text() == dst.read_text():
                return False
        except Exception:
            pass
        # Backup existing file
        backup = dst.with_suffix(dst.suffix + ".bak")
        shutil.copy2(dst, backup)

    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return True


def restore_memory(agent_root):
    """Restore all personalized memory files."""
    config_root = Path(__file__).parent
    memory_src = config_root / "memory"
    memory_dst = agent_root / "memory"

    if not memory_src.exists():
        print(f"[WARN] No memory/ found in {config_root}")
        return 0

    count = 0
    for item in memory_src.rglob("*"):
        if item.is_file() and not item.name.startswith((".DS_Store", "__pycache__")):
            rel = item.relative_to(memory_src)
            dst = memory_dst / rel
            if copy_if_changed(item, dst):
                print(f"  {rel}")
                count += 1

    return count


def restore_assets(agent_root):
    """Restore personalized asset templates."""
    config_root = Path(__file__).parent
    assets_src = config_root / "templates"
    assets_dst = agent_root / "assets"

    if not assets_src.exists():
        return 0

    count = 0
    for item in assets_src.rglob("*"):
        if item.is_file():
            rel = item.relative_to(assets_src)
            dst = assets_dst / rel
            if copy_if_changed(item, dst):
                print(f"  templates/{rel}")
                count += 1

    return count


def main():
    agent_root = detect_agent_root(sys.argv[1] if len(sys.argv) > 1 else None)

    if not agent_root:
        print("ERROR: Cannot find GenericAgent directory.")
        print("Usage: python restore.py /path/to/GenericAgent")
        print("   or: GA_AGENT_DIR=/path/to/GA python restore.py")
        sys.exit(1)

    if not (agent_root / "ga.py").exists():
        print(f"ERROR: {agent_root} does not look like GenericAgent (ga.py not found)")
        sys.exit(1)

    print(f"GenericAgent: {agent_root}")
    print(f"Config source: {Path(__file__).parent}")
    print()

    total = 0

    print("Restoring memory files...")
    total += restore_memory(agent_root)

    print("\nRestoring asset templates...")
    total += restore_assets(agent_root)

    print(f"\nRestored {total} files.")
    print("Done. Run GenericAgent as usual.")


if __name__ == "__main__":
    main()
