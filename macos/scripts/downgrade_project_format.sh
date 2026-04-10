#!/usr/bin/env bash
set -euo pipefail

PBXPROJ_PATH="${1:-Panini.xcodeproj/project.pbxproj}"
TARGET_OBJECT_VERSION="${GRAMMARAI_PBX_OBJECT_VERSION:-60}"

if [[ ! -f "$PBXPROJ_PATH" ]]; then
  exit 0
fi

python3 - <<'PY' "$PBXPROJ_PATH" "$TARGET_OBJECT_VERSION"
from pathlib import Path
import re
import sys

pbxproj = Path(sys.argv[1])
target = sys.argv[2]
content = pbxproj.read_text(encoding="utf-8")

content = re.sub(r"objectVersion = \d+;", f"objectVersion = {target};", content)
content = re.sub(
    r"preferredProjectObjectVersion = \d+;",
    f"preferredProjectObjectVersion = {target};",
    content,
)

pbxproj.write_text(content, encoding="utf-8")
PY

echo "Patched $PBXPROJ_PATH to objectVersion=$TARGET_OBJECT_VERSION"
