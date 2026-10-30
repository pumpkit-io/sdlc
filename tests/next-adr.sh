#!/usr/bin/env bash
# Drives skills/domain-modeling/scripts/next-adr.sh against scratch repos and checks the numbers it claims.
# Usage: tests/next-adr.sh. Scratch repos go under $TMPDIR.
set -u

script="$(cd "$(dirname "$0")/.." && pwd)/skills/domain-modeling/scripts/next-adr.sh"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/next-adr-test.XXXXXX")"
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

next() { bash "$script" "$@" 2>/dev/null; }

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

add_adr() {
  local repo="$1" file="$2"
  mkdir -p "$repo/$(dirname "$file")"
  printf '# x\n' > "$repo/$file"
  git -C "$repo" add "$file"
  git -C "$repo" commit -q -m "adr $file"
}

echo "# no ADRs yet"
repo="$(new_repo empty)"
check "starts at 0001" "0001" "$(cd "$repo" && next)"
check "a second claim before any file is written" "0002" "$(cd "$repo" && next)"

echo "# origin"
repo="$(new_repo origin)"
git clone -q "$scratch/origin-origin.git" "$scratch/origin-other" 2>/dev/null
add_adr "$scratch/origin-other" docs/adr/0003-x.md
git -C "$scratch/origin-other" push -q origin main
check "after the highest on origin/main" "0004" "$(cd "$repo" && next)"

echo "# from a subdirectory"
repo="$(new_repo subdir)"
add_adr "$repo" docs/adr/0004-x.md
git -C "$repo" push -q origin main
git -C "$repo" checkout -q -b feat/sub
git -C "$repo" rm -q docs/adr/0004-x.md && git -C "$repo" commit -q -m drop
mkdir -p "$repo/src/app"
check "committed ADRs found from a subdirectory" "0005" "$(cd "$repo/src/app" && next)"

echo "# local branch"
repo="$(new_repo branch)"
git -C "$repo" checkout -q -b feat/other
add_adr "$repo" docs/adr/0005-x.md
git -C "$repo" checkout -q main
check "after the highest on any local branch" "0006" "$(cd "$repo" && next)"

echo "# uncommitted file in another worktree"
repo="$(new_repo worktree)"
git -C "$repo" worktree add -q -b feat/wt "$repo/.claude/worktrees/wt" 2>/dev/null
mkdir -p "$repo/.claude/worktrees/wt/docs/adr"
printf '# x\n' > "$repo/.claude/worktrees/wt/docs/adr/0007-x.md"
check "after an uncommitted file in a worktree" "0008" "$(cd "$repo" && next)"
check "the same from inside the worktree" "0009" "$(cd "$repo/.claude/worktrees/wt" && next)"

echo "# parallel sessions"
repo="$(new_repo parallel)"
for i in 1 2 3 4 5 6 7 8; do (cd "$repo" && next > "$scratch/claim-$i") & done
wait
check "eight parallel claims are distinct" "8" "$(cat "$scratch"/claim-* | sort -u | wc -l | tr -d ' ')"
check "and run from 0001 to 0008" "0001 0008" "$(cat "$scratch"/claim-* | sort | sed -n '1p;$p' | tr '\n' ' ' | sed 's/ $//')"

echo "# folder per context"
repo="$(new_repo contexts)"
add_adr "$repo" docs/adr/0002-x.md
check "a context folder numbers on its own" "0001" "$(cd "$repo" && next src/billing/docs/adr)"
check "the root folder keeps its own count" "0003" "$(cd "$repo" && next docs/adr)"

echo
if [ "$failures" -eq 0 ]; then echo "all passed"; else echo "$failures failed"; exit 1; fi
