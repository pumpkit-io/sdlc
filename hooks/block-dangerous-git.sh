#!/usr/bin/env bash
# sdlc git guardrails: PreToolUse hook for the Bash tool.
# Exit 0 lets the command run. Exit 2 blocks it, and stderr is shown to the agent.
# Adapted from skills/misc/git-guardrails-claude-code. Requires jq.

PUSH_POLICY="branches"   # "branches": feature-branch pushes allowed. "none": every push blocked.

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
[ -z "$cmd" ] && exit 0

block() {
  printf 'BLOCKED by sdlc guardrails (%s). Do not retry or work around this: ask the user to run it themselves if it is really needed.\n' "$1" >&2
  exit 2
}
has() { printf '%s' "$cmd" | grep -Eq -- "$1"; }

G='git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+'

# Destructive or hard-to-reverse operations: always blocked.
has "${G}reset[[:space:]].*--hard"                                   && block 'git reset --hard'
has "${G}clean[[:space:]]+(.*[[:space:]])?-[a-zA-Z]*f"               && block 'git clean -f'
has "${G}branch[[:space:]]+(.*[[:space:]])?-D"                       && block 'git branch -D'
has "${G}(checkout|restore)[[:space:]]+(.*[[:space:]])?\.([[:space:];&|]|$)" && block 'discarding all working-tree changes'
has 'gh[[:space:]]+pr[[:space:]]+merge'                              && block 'merging a PR is for the human'
has 'gh[[:space:]]+repo[[:space:]]+delete'                           && block 'deleting a repository'
has 'gh[[:space:]]+repo[[:space:]]+edit.*--visibility'               && block 'changing repository visibility'

if has "${G}push"; then
  [ "$PUSH_POLICY" = "none" ] && block 'git push is disabled'
  has 'push[[:space:]].*(--force|--force-with-lease|--mirror|--delete)'      && block 'force, mirror or delete push'
  has 'push([[:space:]].*)?[[:space:]]-[a-zA-Z]*[fd][a-zA-Z]*([[:space:]]|$)' && block 'force or delete push'
  has 'push([[:space:]].*)?[[:space:]]\+'                                     && block 'force push via +refspec'
  has 'push([[:space:]].*)?[[:space:]]:[^[:space:]]'                          && block 'deleting a remote branch'
  has 'push([[:space:]].*)?[[:space:]:/](main|master)([[:space:]]|$)'        && block 'push to main/master'
  branch="$(git -C "${cwd:-.}" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  case "$branch" in main|master) block "push while on $branch" ;; esac
fi
exit 0
