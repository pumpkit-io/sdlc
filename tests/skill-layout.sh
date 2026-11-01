#!/usr/bin/env bash
# Checks that every skill sits in the folder for its type and that the plugin manifest lists each skill once.
# Usage: tests/skill-layout.sh. Needs jq.
set -u

root="$(cd "$(dirname "$0")/.." && pwd)"
. "$(dirname "$0")/lib.sh"

skill_type() {
  local file="$1"
  if grep -q '^disable-model-invocation: true' "$file"; then echo commands
  elif grep -q '^user-invocable: false' "$file"; then echo reference
  else echo auto
  fi
}

listed="$(jq -r '.skills[]' "$root/.claude-plugin/plugin.json" | sort)"
found=""
for file in "$root"/skills/*/*/SKILL.md; do
  dir="$(dirname "$file")"
  name="$(basename "$dir")"
  folder="$(basename "$(dirname "$dir")")"
  check "$name sits in skills/$folder/" "$(skill_type "$file")" "$folder"
  found="$found./skills/$folder/$name"$'\n'
done
check "the manifest lists each skill once, by its path" "$(printf '%s' "$found" | sort)" "$listed"

stray="$(find "$root/skills" -maxdepth 2 -name SKILL.md)"
check "no skill sits directly under skills/<type>/ without its own folder" "" "$stray"

echo "# retired terms"
retired="integration branch"
planted="$(mktemp -d)"
mkdir -p "$planted/skills/auto/planted"
printf 'Merge each Ticket into the %s.\n' "$retired" > "$planted/skills/auto/planted/SKILL.md"
check "the check sees a planted retired term" "skills/auto/planted/SKILL.md" "$(cd "$planted" && grep -rli "$retired" skills)"
rm -rf "$planted"
check "no skill names the retired term" "" "$(cd "$root" && grep -rli "$retired" skills)"

[ "$failures" -eq 0 ]
