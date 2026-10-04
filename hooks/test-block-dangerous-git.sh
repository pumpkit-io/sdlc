#!/usr/bin/env bash
# Pipes sample PreToolUse payloads through block-dangerous-git.sh and checks exit codes:
# 2 for blocked commands, 0 for allowed ones. Run after changing the hook. Requires jq and git.
set -u
HOOK="${HOOK:-$(cd "$(dirname "$0")" && pwd)/block-dangerous-git.sh}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkrepo() { git init -q -b main "$1" && git -C "$1" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init; }
ON_MAIN="$TMP/on-main"; mkrepo "$ON_MAIN"
ON_FEAT="$TMP/on-feat"; mkrepo "$ON_FEAT"; git -C "$ON_FEAT" checkout -q -b feat

fails=0
check() { # check <expected-exit> <cwd> <command>
  local got
  jq -n --arg c "$3" --arg d "$2" '{tool_input:{command:$c},cwd:$d}' | "$HOOK" 2>/dev/null
  got=$?
  if [ "$got" = "$1" ]; then printf 'ok    %s  %s\n' "$got" "$3"; else printf 'FAIL  want %s got %s  %s\n' "$1" "$got" "$3"; fails=$((fails + 1)); fi
}

# Blocked
check 2 "$ON_FEAT" 'git push origin main'
check 2 "$ON_FEAT" 'git push --force origin feat'
check 2 "$ON_FEAT" 'git push -f origin feat'
check 2 "$ON_FEAT" 'git push origin +feat'
check 2 "$ON_FEAT" 'git push origin :feat'
check 2 "$ON_MAIN" 'git push'
check 2 "$ON_FEAT" "cd $ON_MAIN && git push"
check 2 "$ON_FEAT" "git -C $ON_MAIN push"
check 2 "$ON_FEAT" 'git checkout main && git push'
check 2 "$ON_MAIN" 'git checkout README.md && git push'
check 2 "$ON_FEAT" 'git reset --hard'
check 2 "$ON_FEAT" 'gh pr merge 1'

# Allowed
check 0 "$ON_FEAT" 'git push -u origin feat'
check 0 "$ON_FEAT" 'git push -u origin feat && gh pr create --base main'
check 0 "$ON_MAIN" 'git checkout -q -b feat2 && git add -A && git commit -m x && git push -u origin feat2'
check 0 "$ON_MAIN" "cd $ON_FEAT && git push -u origin feat"
check 0 "$ON_MAIN" "git -C $ON_FEAT push -u origin feat"
check 0 "$ON_FEAT" "$(printf 'cat > notes.md <<X\nnever git push to main\nX')"
check 0 "$ON_MAIN" 'git status'

[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
