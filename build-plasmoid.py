#!/usr/bin/env python3
"""Build dist/aurora.plasmoid from the package directory."""
from __future__ import annotations

import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / 'package'
TARGET = ROOT / 'dist/aurora.plasmoid'
SKIP_DIRS = {'__pycache__'}


def main() -> int:
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(TARGET, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(SOURCE.rglob('*')):
            relative = path.relative_to(SOURCE)
            if not path.is_file() or path.suffix == '.pyc':
                continue
            if any(part in SKIP_DIRS for part in relative.parts):
                continue
            archive.write(path, relative.as_posix())
    print(TARGET)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
