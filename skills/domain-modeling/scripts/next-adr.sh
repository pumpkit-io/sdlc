#!/usr/bin/env bash
# Claims the next free ADR number for one ADR folder and prints it as four digits.
# Usage: next-adr.sh [<adr folder, from the repo root>]   (default docs/adr)
# Run from any worktree of the repo. Two runs never print the same number.
set -u

dir="${1:-docs/adr}"
dir="${dir%/}"

common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || {
  echo "next-adr: not inside a git repository" >&2
  exit 1
}

# Claims live in the shared git dir, so every worktree on this machine sees them.
claims="$common/sdlc/adr-claims/$(printf '%s' "$dir" | tr '/' '_')"
mkdir -p "$claims"

git remote get-url origin >/dev/null 2>&1 && git fetch -q origin 2>/dev/null

highest="$(
  {
    refs="$(git for-each-ref --format='%(refname)' refs/heads)"
    origin_head="$(git symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null)" && refs="$refs $origin_head"
    for ref in $refs; do git ls-tree --name-only "$ref" "$dir/" 2>/dev/null; done
    git worktree list --porcelain | sed -n 's/^worktree //p' | while IFS= read -r wt; do
      ls "$wt/$dir" 2>/dev/null
    done
    ls "$claims"
  } | sed 's|.*/||' | grep -o '^[0-9]\{4\}' | sort -u | tail -n 1
)"

n=$((10#${highest:-0} + 1))
# mkdir is atomic, so a parallel run that loses the race moves on to the next number.
until mkdir "$claims/$(printf '%04d' "$n")" 2>/dev/null; do
  n=$((n + 1))
done
printf '%04d\n' "$n"
