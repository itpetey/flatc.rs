#!/usr/bin/env bash
set -euo pipefail

file_path="${1:-Cargo.toml}"
suffix_input="${2:-}"

if [ -z "$suffix_input" ]; then
  echo "suffix input is required" >&2
  exit 1
fi

suffix="${suffix_input#v}"

if [ ! -f "$file_path" ] && [ -n "${GITHUB_WORKSPACE:-}" ]; then
  workspace_candidate="${GITHUB_WORKSPACE%/}/$file_path"
  if [ -f "$workspace_candidate" ]; then
    file_path="$workspace_candidate"
  fi
fi

if [ ! -f "$file_path" ]; then
  echo "Cargo.toml not found at $file_path" >&2
  exit 1
fi

new_version="$(python - "$file_path" "$suffix" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
suffix = sys.argv[2]
text = path.read_text()
m = re.search(r'^(\\s*version\\s*=\\s*")([^"]+)(")', text, flags=re.M)
if not m:
    raise SystemExit(f"version not found in {path}")
version = m.group(2)
base = version.split("+", 1)[0]
new_version = f"{base}+{suffix}"
new_text = re.sub(r'^(version\\s*=\\s*")[^"]+(")', r'\\1' + new_version + r'\\2', text, flags=re.M)
if new_text != text:
    path.write_text(new_text)
print(new_version)
PY
)"

{
  echo "version=$new_version"
  echo "tag=v$new_version"
} >> "$GITHUB_OUTPUT"
