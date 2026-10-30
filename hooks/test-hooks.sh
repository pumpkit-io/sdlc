#!/usr/bin/env bash
# Pipes each case's payload through its hook and checks the exit code: 2 for block, 0 for allow.
# Usage: hooks/test-hooks.sh. Prints every failing case and exits 1 if any fails.
# Requires jq, perl and git, like the hooks themselves.

here="$(cd "$(dirname "$0")" && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
unset SDLC_ALLOW_MAIN_CHECKOUT
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

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

# Main checkouts for the guard cases, each with a linked worktree at <worktrees folder>/x.
# main_repo <name> <instruction file> <its text> [<worktrees folder override>]
main_repo() {
  local r="$scratch/$1" folder="${4:-.claude/worktrees}"
  git init -q "$r"
  printf '%s\n' "$3" >"$r/$2"
  if [ -n "${4:-}" ]; then
    mkdir -p "$r/docs/agents"
    printf '# Worktrees\n\n## Folder\n\n`%s`\n' "$4" >"$r/docs/agents/worktrees.md"
  fi
  git -C "$r" add -A
  git -C "$r" commit -qm init
  git -C "$r" worktree add -q -b x "$r/$folder/x"
}
rule="$(printf '# Agents\n\n### Worktrees\n\nNever edit files or commit in the main checkout.')"
main_repo ruled AGENTS.md "$rule"
main_repo older CLAUDE.md "$rule"
main_repo moved AGENTS.md "$rule" trees
main_repo plain AGENTS.md '# Agents'
main="$scratch/ruled"
wt="$main/.claude/worktrees/x"

edit() { check "$1" guard-main-checkout "$2" file_path "$3"; }
run() { check "$1" guard-main-checkout "$2" command "$3"; }

edit block "$main" "$main/src/app.js"
edit block "$main" 'src/app.js'
edit block "$main" "$main/AGENTS.md"
edit block "$wt" "$main/src/app.js"
edit block "$wt" "$wt/../../../src/app.js"
edit block "$scratch" "$main/src/app.js"
SDLC_ALLOW_MAIN_CHECKOUT=1 edit allow "$main" "$main/src/app.js"
edit allow "$wt" "$wt/src/app.js"
edit allow "$main" "$wt/src/app.js"
edit allow "$main" "$main/.claude/worktrees/new/src/app.js"
edit allow "$main" "$main/.sdlc/lock"
edit allow "$main" "$main/docs/architecture-improvements/app-2026-10-30.md"
edit allow "$main" "$scratch/notes.md"
edit allow "$main" "$HOME/.claude/projects/x/memory/MEMORY.md"
edit block "$scratch/older" "$scratch/older/src/app.js"
edit allow "$scratch/moved" "$scratch/moved/trees/x/src/app.js"
edit block "$scratch/moved" "$scratch/moved/.claude/worktrees/x/src/app.js"
edit allow "$scratch/plain" "$scratch/plain/src/app.js"
check block guard-main-checkout "$main" notebook_path "$main/analysis.ipynb"

run block "$main" 'git commit -m x'
run allow "$wt" 'git commit -m x'
run block "$wt" "git -C $main commit -m x"
run block "$scratch" "git -C $main commit -m x"
run allow "$main" 'git -C .claude/worktrees/x commit -m x'
run allow "$main" 'cd .claude/worktrees/x && git commit -m x'
run block "$wt" "cd $main && git commit -m x"
run block "$main" 'git -c user.name=x commit -m x'
run block "$main" 'git status && git add .'
run block "$main" 'git checkout feat/x'
run block "$main" 'git checkout -b feat/y'
run block "$main" 'git switch feat/x'
run block "$main" 'git merge feat/x'
run allow "$main" 'git merge --ff-only origin/main'
run block "$main" 'git pull'
run block "$main" 'git pull --rebase origin main'
run allow "$main" 'git pull --ff-only'
run block "$main" 'git rebase origin/main'
run block "$main" 'git stash'
run block "$main" 'git stash pop'
run allow "$main" 'git stash list'
run block "$main" 'git cherry-pick abc123'
run block "$main" 'git revert HEAD'
run block "$main" 'git apply fix.patch'
run allow "$main" 'git apply --check fix.patch'
run block "$main" 'git am fix.patch'
run allow "$main" 'git status'
run allow "$main" 'git log --oneline -5'
run allow "$main" 'git fetch origin'
run allow "$main" 'git worktree add -b feat/y .claude/worktrees/y origin/main'
run allow "$main" 'echo "git commit -m x"'
run allow "$wt" 'git commit -m "never git add in the main checkout"'
SDLC_ALLOW_MAIN_CHECKOUT=1 run allow "$main" 'git commit -m x'
run block "$scratch/older" 'git commit -m x'
run allow "$scratch/plain" 'git commit -m x'

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
