#!/usr/bin/env python3
"""Create a source-only release archive without Git history or private state."""
import argparse
from pathlib import Path
import tarfile

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("output", type=Path, help="New .tar.gz archive (must not exist)")
args = parser.parse_args()
files = [ROOT / name for name in ("init.el", "early-init.el", "README.md", ".gitignore", "CONTRIBUTING.md", "CHANGELOG.md")]
for folder, pattern in (("lisp", "*.el"), ("examples", "*.el"), ("tests", "*.el"), ("scripts", "*.el"), ("scripts", "*.py"), ("docs", "*.md"),
                        (".github", "*.md"), (".github/workflows", "*.yml"), (".github/ISSUE_TEMPLATE", "*.yml")):
    files.extend(sorted((ROOT / folder).glob(pattern)))
# Never follow a symlink out to a machine-specific file.
for path in files:
    if path.is_symlink() or not path.is_file():
        raise SystemExit(f"Refusing non-regular source file: {path}")
def public_metadata(info):
    info.uid = info.gid = 0
    info.uname = info.gname = ""
    info.mtime = 0
    info.pax_headers = {}
    return info

with args.output.open("xb") as output:
    with tarfile.open(fileobj=output, mode="w:gz") as archive:
        for path in files:
            archive.add(path, arcname=str(Path("LazyEmacs") / path.relative_to(ROOT)), recursive=False, filter=public_metadata)
print(f"Exported {len(files)} source files to {args.output}")
