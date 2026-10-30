#!/usr/bin/env bash
# Drives skills/worktrees/scripts/worktree.sh against scratch repos and checks its output and exit codes.
# Usage: tests/worktrees.sh. Scratch repos go under $TMPDIR.
set -u

script="$(cd "$(dirname "$0")/.." && pwd)/skills/worktrees/scripts/worktree.sh"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/worktrees-test.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
failures=0

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    printf 'ok   %s\n' "$name"
  else
    printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$name" "$expected" "$actual"
    failures=$((failures + 1))
  fi
}

contains() {
  local name="$1" needle="$2" haystack="$3"
  case "$haystack" in
    *"$needle"*) printf 'ok   %s\n' "$name" ;;
    *) printf 'FAIL %s\n  expected to contain: %s\n  actual: %s\n' "$name" "$needle" "$haystack"
       failures=$((failures + 1)) ;;
  esac
}

wt() { bash "$script" "$@"; }

# A bare origin with one commit on main, cloned as the Main checkout.
new_repo() {
  local name="$1"
  git init -q --bare -b main "$scratch/$name-origin.git"
  git clone -q "$scratch/$name-origin.git" "$scratch/$name" 2>/dev/null
  git -C "$scratch/$name" commit -q --allow-empty -m init
  git -C "$scratch/$name" push -q origin main
  git -C "$scratch/$name" remote set-head origin main
  printf '%s' "$scratch/$name"
}

# Backdates the lock, every file and the last commit so the lock reads as stale.
age_worktree() {
  local dir="$1"
  printf '%s\nold session\n' "$(( $(date +%s) - 3 * 3600 ))" > "$dir/.sdlc/lock"
  find "$dir" -path "$dir/.git" -prune -o -exec touch -t 202001010000 {} +
  GIT_COMMITTER_DATE="2020-01-01T00:00:00" git -C "$dir" commit -q --allow-empty --amend --no-edit
}

echo "# slug"
check "Portless example" "login-flow-v2" "$(wt slug feat/Login_Flow.v2)"
check "repeats collapsed and trimmed" "a-b" "$(wt slug 'fix/--A__b--')"
check "no prefix" "chore-x" "$(wt slug chore-x)"
check "capped at 63" "$(printf 'a%.0s' $(seq 63))" "$(wt slug "feat/$(printf 'a%.0s' $(seq 70))")"

echo "# main"
repo="$(new_repo main)"
check "from the main checkout" "$(cd "$repo" && pwd -P)" "$(cd "$repo" && wt main)"

echo "# create"
path="$(cd "$repo" && wt create feat/Login_Flow.v2 2>/dev/null | tail -n 1)"
check "path under the main checkout" "$(cd "$repo" && pwd -P)/.claude/worktrees/login-flow-v2" "$path"
check "branch" "feat/Login_Flow.v2" "$(git -C "$path" branch --show-current)"
check "based on origin/main" "$(git -C "$repo" rev-parse origin/main)" "$(git -C "$path" rev-parse HEAD~1)"
check "gitignore commit" "chore: ignore worktrees and session locks" "$(git -C "$path" log -1 --format=%s)"
check "gitignore covers locks" "0" "$(git -C "$path" check-ignore -q .sdlc/lock; echo $?)"
contains "no worktrees doc" "No docs/agents/worktrees.md" "$(cd "$repo" && wt create feat/other 2>&1)"
check "main checkout untouched" "main" "$(git -C "$repo" branch --show-current)"

nested="$(cd "$path" && wt create fix/nested 2>/dev/null | tail -n 1)"
check "never nested" "$(cd "$repo" && pwd -P)/.claude/worktrees/nested" "$nested"
check "existing worktree reused" "$path" "$(cd "$repo" && wt create feat/Login_Flow.v2 2>/dev/null | tail -n 1)"
out="$(cd "$repo" && wt create chore/login-flow-v2 2>&1)"; code=$?
check "slug clash refused" "1" "$code"
contains "slug clash names the holder" "feat/Login_Flow.v2" "$out"

git -C "$repo" branch -q feat/linked
git -C "$repo" push -q origin feat/linked
git -C "$repo" branch -q -D feat/linked
linked="$(cd "$repo" && wt create feat/linked 2>/dev/null | tail -n 1)"
check "remote branch gets a worktree" "$(git -C "$repo" rev-parse origin/feat/linked)" "$(git -C "$linked" rev-parse HEAD~1)"

git -C "$repo" checkout -q -b feat/mine
out="$(cd "$repo" && wt create feat/mine 2>&1)"; code=$?
check "branch in main checkout refused" "1" "$code"
contains "branch in main checkout message" "checked out in the main checkout" "$out"
check "user's checkout not switched" "feat/mine" "$(git -C "$repo" branch --show-current)"
git -C "$repo" checkout -q main

echo "# bootstrap"
boot="$(new_repo boot)"
mkdir -p "$boot/docs/agents"
cat > "$boot/docs/agents/worktrees.md" <<'EOF'
# Worktrees

## Copy

- `.env`
- `apps/web/.env.local`

## Install

```sh
touch installed
```
EOF
printf '.claude/worktrees/\n.sdlc/\n.env\napps/web/.env.local\ninstalled\n' > "$boot/.gitignore"
git -C "$boot" add -A && git -C "$boot" commit -q -m doc && git -C "$boot" push -q origin main
echo SECRET=1 > "$boot/.env"
mkdir -p "$boot/apps/web" && echo X=1 > "$boot/apps/web/.env.local"
bpath="$(cd "$boot" && wt create feat/boot 2>/dev/null | tail -n 1)"
check "copies listed files" "SECRET=1" "$(cat "$bpath/.env")"
check "copies nested files" "X=1" "$(cat "$bpath/apps/web/.env.local")"
check "runs install" "yes" "$([ -f "$bpath/installed" ] && echo yes)"
check "no gitignore commit when covered" "doc" "$(git -C "$bpath" log -1 --format=%s)"

echo "# lock"
check "take" "0" "$(wt lock "$path" "session A" >/dev/null 2>&1; echo $?)"
check "same holder retakes" "0" "$(wt lock "$path" "session A" >/dev/null 2>&1; echo $?)"
out="$(wt lock "$path" "session B" 2>&1)"; code=$?
check "busy" "3" "$code"
contains "busy names the holder" "session A" "$out"
age_worktree "$path"
out="$(wt lock "$path" "session B" 2>&1)"; code=$?
check "stale" "4" "$code"
contains "stale names the holder" "old session" "$out"
check "take over" "0" "$(wt lock --take-over "$path" "session B" >/dev/null 2>&1; echo $?)"
check "holder after take over" "session B" "$(sed -n 2p "$path/.sdlc/lock")"
check "release" "no" "$(wt release "$path"; [ -e "$path/.sdlc/lock" ] && echo yes || echo no)"
check "lock in main checkout refused" "1" "$(wt lock "$repo" "x" >/dev/null 2>&1; echo $?)"

echo "# list"
wt lock "$nested" "session C" >/dev/null 2>&1
listing="$(cd "$repo" && wt list)"
row="$(printf '%s\n' "$listing" | awk -F '\t' '$1 == "nested"')"
check "list row" "nested	fix/nested	1	0	session C	0m	-" "$row"
mkdir -p "$linked/scripts"
printf '#!/bin/sh\n[ "$1" = status ] && echo stopped && exit 3\n' > "$linked/scripts/dev-stack"
chmod +x "$linked/scripts/dev-stack"
row="$(cd "$repo" && wt list | awk -F '\t' '$1 == "linked"')"
check "list stack status" "stopped" "$(printf '%s' "$row" | cut -f 7)"
check "list free lock" "-" "$(printf '%s' "$row" | cut -f 5)"

echo "# finish"
fin="$(cd "$repo" && wt create feat/fin 2>/dev/null | tail -n 1)"
echo change > "$fin/file.txt"
out="$(cd "$repo" && wt finish "$fin" 2>&1)"; code=$?
check "dirty refused" "1" "$code"
contains "dirty lists the files" "file.txt" "$out"
git -C "$fin" add file.txt && git -C "$fin" commit -q -m work
out="$(cd "$repo" && wt finish "$fin" 2>&1)"; code=$?
check "unmerged unpushed refused" "5" "$code"
out="$(cd "$fin" && wt finish "$fin" --pr-open 2>&1)"; code=$?
check "inside the worktree refused" "1" "$code"
contains "inside says leave" "Leave" "$out"
wt lock "$fin" "session D" >/dev/null 2>&1
check "locked refused" "3" "$(cd "$repo" && wt finish "$fin" --pr-open >/dev/null 2>&1; echo $?)"
wt release "$fin"
printf '#!/bin/sh\n[ "$1" = destroy ] && touch "%s/destroyed"\nexit 0\n' "$scratch" > "$fin/scripts-dev-stack"
mkdir -p "$fin/scripts" && mv "$fin/scripts-dev-stack" "$fin/scripts/dev-stack" && chmod +x "$fin/scripts/dev-stack"
git -C "$fin" add scripts && git -C "$fin" commit -q -m contract
out="$(cd "$repo" && wt finish "$fin" --pr-open 2>&1)"; code=$?
check "finish with open PR" "0" "$code"
check "worktree removed" "no" "$([ -d "$fin" ] && echo yes || echo no)"
check "dev stack destroyed" "yes" "$([ -f "$scratch/destroyed" ] && echo yes)"
check "unmerged branch kept" "feat/fin" "$(git -C "$repo" branch --list feat/fin --format='%(refname:short)')"

pushed="$(cd "$repo" && wt create feat/pushed 2>/dev/null | tail -n 1)"
git -C "$pushed" push -q -u origin feat/pushed 2>/dev/null
check "pushed branch finishes" "0" "$(cd "$repo" && wt finish "$pushed" >/dev/null 2>&1; echo $?)"

integ="$(cd "$repo" && wt create feat/integ 2>/dev/null | tail -n 1)"
impl="$(cd "$repo" && wt create integ-t1 feat/integ 2>/dev/null | tail -n 1)"
git -C "$impl" commit -q --allow-empty -m ticket
check "unmerged into integration refused" "5" "$(cd "$repo" && wt finish "$impl" --merged-into feat/integ >/dev/null 2>&1; echo $?)"
git -C "$integ" merge -q --no-ff --no-edit integ-t1
out="$(cd "$repo" && wt finish "$impl" --merged-into feat/integ 2>&1)"; code=$?
check "merged into integration finishes" "0" "$code"
check "implementer branch deleted" "" "$(git -C "$repo" branch --list integ-t1)"

echo "# sweep"
sw="$(new_repo sweep)"
merged="$(cd "$sw" && wt create feat/merged 2>/dev/null | tail -n 1)"
git -C "$merged" push -q origin HEAD:main
dirty="$(cd "$sw" && wt create feat/dirty 2>/dev/null | tail -n 1)"
git -C "$dirty" push -q origin HEAD:main
echo x > "$dirty/x.txt"
busy="$(cd "$sw" && wt create feat/busy 2>/dev/null | tail -n 1)"
git -C "$busy" reset -q --hard origin/main
wt lock "$busy" "session E" >/dev/null 2>&1
open="$(cd "$sw" && wt create feat/open 2>/dev/null | tail -n 1)"
git -C "$open" commit -q --allow-empty -m wip
out="$(cd "$sw" && wt sweep 2>&1)"
check "merged worktree finished" "no" "$([ -d "$merged" ] && echo yes || echo no)"
check "merged branch deleted" "" "$(git -C "$sw" branch --list feat/merged)"
contains "dirty left with reason" "dirty: uncommitted changes" "$out"
contains "busy left with reason" "busy: locked by session E" "$out"
contains "open left with reason" "open: not merged" "$out"
check "dirty kept" "yes" "$([ -d "$dirty" ] && echo yes)"

echo
if [ "$failures" -eq 0 ]; then echo "all passed"; else echo "$failures failed"; exit 1; fi
