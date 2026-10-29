#!/usr/bin/env bash
# sdlc comment slop check: PreToolUse hook for the Bash tool.
# Before a `git commit`, runs comment-slop.pl over the comment lines the commit adds.
# Exit 0 lets the commit run. Exit 2 blocks it, and stderr is shown to the agent.
# Detection is loose on purpose: a missed commit is still caught in CI, and a false match only
# lints the staged diff. Requires jq and perl.

here="$(cd "$(dirname "$0")" && pwd)"
input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -z "$cmd" ] && exit 0

# Quoted strings go first, so a commit message or PR body that mentions `git commit` doesn't count.
bare="$(printf '%s' "$cmd" | perl -0pe 's/\x27[^\x27]*\x27|"(?:[^"\\]|\\.)*"/_/gs')"
printf '%s' "$bare" | grep -Eq '(^|[;&|(])\s*([A-Za-z_][A-Za-z0-9_]*=\S*\s+)*git(\s+-[Cc]\s+\S+|\s+--?[a-z-]+(=\S+)?)*\s+commit(\s|$)' || exit 0
printf '%s' "$cmd" | grep -Eq '(^|\s)SDLC_ALLOW_SLOP=1\s' && exit 0

dir="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
[ -n "$dir" ] && cd "$dir" 2>/dev/null
c_dir="$(printf '%s' "$bare" | perl -ne 'print $1 if /\bgit\s+(?:\S+\s+)*?-C\s+(\S+)/')"
[ -n "$c_dir" ] && cd "$c_dir" 2>/dev/null
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# `commit -a` also takes the unstaged changes to tracked files.
if printf '%s' "$bare" | grep -Eq '\scommit\s(.*\s)?(-[A-Za-z]*a[A-Za-z]*|--all)(\s|$)'; then
  diff="$(git diff -U0 HEAD 2>/dev/null || git diff -U0 --cached)"
else
  diff="$(git diff -U0 --cached)"
fi
[ -z "$diff" ] && exit 0

findings="$(printf '%s\n' "$diff" | perl "$here/comment-slop.pl")" && exit 0
{
  printf 'BLOCKED by the sdlc comment slop check. The comments this commit adds break the code-comments skill:\n\n%s\n\n' "$findings"
  printf 'Load the code-comments skill, fix these comments, stage the fixes and commit again. If a finding is a false positive, tell the user which one and why, then rerun the same commit prefixed with SDLC_ALLOW_SLOP=1.\n'
} >&2
exit 2
