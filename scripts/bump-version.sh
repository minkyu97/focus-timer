#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <version>" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 64
fi

marketing_version="$1"

if [[ ! "$marketing_version" =~ ^[0-9]+(\.[0-9]+){2}(-[A-Za-z0-9][A-Za-z0-9.-]*)?$ ]]; then
  echo "Invalid marketing version: $marketing_version" >&2
  echo "Expected format: 0.0.6 or 0.0.6-hotfix" >&2
  exit 64
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
project_file="${PROJECT_FILE:-$repo_root/focus-timer.xcodeproj/project.pbxproj}"

if [[ ! -f "$project_file" ]]; then
  echo "Project file not found: $project_file" >&2
  exit 66
fi

current_project_version="$(
  sed -nE 's/^[[:space:]]*CURRENT_PROJECT_VERSION = ([0-9]+);[[:space:]]*$/\1/p' "$project_file" |
    sort -nu |
    tail -n 1
)"

if [[ -z "$current_project_version" ]]; then
  echo "CURRENT_PROJECT_VERSION was not found in $project_file" >&2
  exit 65
fi

next_project_version=$((current_project_version + 1))

perl -0pi -e "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $next_project_version;/g" "$project_file"
perl -0pi -e "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $marketing_version;/g" "$project_file"

echo "Updated MARKETING_VERSION to $marketing_version"
echo "Updated CURRENT_PROJECT_VERSION to $next_project_version"
