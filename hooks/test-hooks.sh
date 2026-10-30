#!/usr/bin/env bash
# Pipes each case's payload through its hook and checks the exit code: 2 for block, 0 for allow.
# Usage: hooks/test-hooks.sh. Prints every failing case and exits 1 if any fails.
# Requires jq, perl and git, like the hooks themselves.

here="$(cd "$(dirname "$0")" && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# Scratch repos for the commit-slop cases, each with one staged file.
scratch_repo() {
  git init -q "$scratch/$1"
  printf '%s\n' "$2" >"$scratch/$1/run.sh"
  git -C "$scratch/$1" add run.sh
}
scratch_repo clean '# Retry once: the mirror drops the first request after idle.'
scratch_repo slop '# Step 1: build the thing'
clean="$scratch/clean"
slop="$scratch/slop"

pass=0
fail=0

# check <block|allow> <hook> <cwd> <command|file_path> <value>
check() {
  local want=0 code payload err
  [ "$1" = block ] && want=2
  payload="$(jq -nc --arg d "$3" --arg k "$4" --arg v "$5" '{cwd: $d, tool_input: {($k): $v}}')"
  err="$(printf '%s' "$payload" | "$here/$2.sh" 2>&1 >/dev/null)"
  code=$?
  if [ "$code" = "$want" ] && { [ "$want" = 0 ] || [ -n "$err" ]; }; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL %s (want %s, got %s) %s: %s\n' "$2" "$1" "$code" "$4" "$5"
    [ -n "$err" ] && printf '     %s\n' "$err"
  fi
}

guard() { check "$1" block-dangerous-git "$clean" command "$2"; }

guard block 'git push --force origin feat/x'
guard block 'git push -f'
guard block 'git push origin +feat/x'
guard block 'git push origin :feat/x'
guard block 'git push --delete origin feat/x'
guard allow 'git push -u origin feat/x'
guard block 'git reset --hard HEAD~1'
guard allow 'git reset --soft HEAD~1'
guard block 'git clean -fd'
guard allow 'git clean -n'
guard block 'git branch -D feat/x'
guard block 'git branch --delete --force feat/x'
guard allow 'git branch -d feat/x'
guard block 'git checkout .'
guard block 'git restore .'
guard block 'git commit --no-verify -m x'
guard block 'git -c core.hooksPath=/dev/null commit -m x'
guard allow 'git commit -m "undo with git reset --hard"'
guard allow 'git push origin feat/x && gh pr create --base main --title "x" --body "no git push --force here"'
guard block 'gh pr merge 12'
guard block 'gh repo delete pumpkit-io/x'
guard block 'gh repo edit --visibility public'
guard block 'gh api -X PUT repos/o/r/pulls/1/merge'
guard block 'gh api -X DELETE repos/o/r'
guard allow 'gh api repos/o/r/pulls/1'
guard block 'sh -c "git reset --hard"'
guard block 'eval "git push --force"'
guard block "$(printf 'bash <<EOF\ngit reset --hard\nEOF')"
guard allow "$(printf 'cat <<EOF\ngit reset --hard\nEOF')"

guard allow 'git worktree remove .claude/worktrees/x'
guard block 'git worktree remove -f .claude/worktrees/x'
guard block 'git worktree remove --force .claude/worktrees/x'
guard block 'git worktree remove .claude/worktrees/x --force'
guard allow 'git worktree prune'

guard block 'portless proxy stop'
guard block 'portless clean'
guard block 'portless hosts clean'
guard block 'portless service uninstall'
guard block 'portless run --force next dev'
guard block 'npx portless clean'
guard allow 'portless alias --remove x'
guard allow 'portless prune'
guard allow 'portless alias x 1234 --force'
guard allow 'portless run next dev'
guard allow 'portless proxy start -p 1355 --no-tls'
guard allow 'git commit -m "never run portless clean"'

slop_check() { check "$1" check-commit-slop "$2" command "$3"; }

slop_check allow "$clean" 'git commit -m "add retry"'
slop_check block "$slop" 'git commit -m "add build"'
slop_check allow "$slop" 'SDLC_ALLOW_SLOP=1 git commit -m "add build"'
slop_check block "$clean" "git -C $slop commit -m x"
slop_check allow "$slop" 'echo "git commit"'
slop_check allow "$slop" 'git status'

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
