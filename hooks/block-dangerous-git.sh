#!/usr/bin/env bash
# sdlc git guardrails: PreToolUse hook for the Bash tool.
# Exit 0 lets the command run. Exit 2 blocks it, and stderr is shown to the agent.
# Adapted from the git-guardrails-claude-code skill in mattpocock/skills. Requires jq.

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

  # Judge each push on its own command segment (split on && || ; | and newlines),
  # so words elsewhere in a compound command, such as a later `--base main` or
  # heredoc text, can't trigger a push rule. Earlier segments still count:
  # `cd`, `git -C` and branch switches change which branch the push runs on.
  dir="${cwd:-.}"
  switched=""
  resolve() { case "$1" in /*) printf '%s' "$1" ;; "~"*) printf '%s%s' "$HOME" "${1#\~}" ;; *) printf '%s/%s' "$dir" "$1" ;; esac; }
  GIT='^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+'
  segments="$(printf '%s\n' "$cmd" | awk '{ gsub(/&&|\|\||;|\|/, "\n"); print }')"

  while IFS= read -r seg; do
    seg="$(printf '%s' "$seg" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    seg_has() { printf '%s' "$seg" | grep -Eq -- "$1"; }

    if seg_has '^cd[[:space:]]+[^[:space:]]+'; then
      target="$(printf '%s' "$seg" | sed -E "s/^cd[[:space:]]+([^[:space:]]+).*/\1/; s/^[\"']//; s/[\"']\$//")"
      dir="$(resolve "$target")"; switched=""
      continue
    fi
    seg_has "$GIT" || continue

    sdir="$dir"
    cdir="$(printf '%s' "$seg" | sed -nE 's/^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*git[[:space:]]+-C[[:space:]]+([^[:space:]]+).*/\2/p')"
    [ -n "$cdir" ] && sdir="$(resolve "$cdir")"

    if seg_has "${GIT}(checkout|switch)[[:space:]]"; then
      # A new branch (-b/-c) or an existing local branch counts as a switch;
      # `git checkout <path>` does not.
      name="$(printf '%s' "$seg" | awk '{ print $NF }')"
      if seg_has '[[:space:]]-[bBcC][[:space:]]' || git -C "$sdir" show-ref --verify --quiet "refs/heads/$name" 2>/dev/null; then
        switched="$name"
      fi
      continue
    fi

    seg_has "${GIT}push" || continue
    seg_has 'push[[:space:]].*(--force|--force-with-lease|--mirror|--delete)'      && block 'force, mirror or delete push'
    seg_has 'push([[:space:]].*)?[[:space:]]-[a-zA-Z]*[fd][a-zA-Z]*([[:space:]]|$)' && block 'force or delete push'
    seg_has 'push([[:space:]].*)?[[:space:]]\+'                                     && block 'force push via +refspec'
    seg_has 'push([[:space:]].*)?[[:space:]]:[^[:space:]]'                          && block 'deleting a remote branch'
    seg_has 'push([[:space:]].*)?[[:space:]:/](main|master)([[:space:]]|$)'        && block 'push to main/master'
    branch="$switched"
    [ -z "$branch" ] && branch="$(git -C "$sdir" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    case "$branch" in main|master) block "push while on $branch" ;; esac
  done <<EOF
$segments
EOF
fi
exit 0
