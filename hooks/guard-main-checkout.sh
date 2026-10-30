#!/usr/bin/env bash
# sdlc main-checkout guard: PreToolUse hook for the file tools and Bash (ADR 0004).
# In a repo whose AGENTS.md or CLAUDE.md has the `### Worktrees` rule, it blocks file edits and the git
# commands that change the checkout in the Main checkout. Exit 0 lets the call run. Exit 2 blocks it,
# and stderr is shown to the agent. SDLC_ALLOW_MAIN_CHECKOUT=1 in the session's environment turns it off.
# Shell redirections into the checkout are not caught: the AGENTS.md rule covers those. Requires jq and perl.

[ "${SDLC_ALLOW_MAIN_CHECKOUT:-}" = 1 ] && exit 0

input="$(cat)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
[ -n "$cwd" ] || cwd="$PWD"

block() {
  printf 'BLOCKED by the sdlc main-checkout guard: %s in the main checkout %s, which belongs to the user.' "$1" "$2" >&2
  printf ' Load the worktrees skill, resolve the worktree for this work, and retry the same change there.' >&2
  printf ' If the user wants this change made in the main checkout itself, tell them it needs a session started with SDLC_ALLOW_MAIN_CHECKOUT=1.\n' >&2
  exit 2
}

# resolve <path> <base>: the absolute physical path, with symlinks resolved in the part that exists.
resolve() {
  perl -MCwd=abs_path -e '
    my ($p, $base) = @ARGV;
    $p = "$base/$p" unless $p =~ m{^/};
    my $rest = "";
    until (-d $p) { $p =~ s{/+([^/]*)$}{}; $rest = "/$1$rest"; $p = "/" if $p eq "" }
    my $r = abs_path($p);
    $r = "" if $r eq "/";
    print "$r$rest\n";
  ' "$1" "$2"
}

# Prints the Main checkout of the repo holding directory $1, if that checkout has the Worktrees rule.
guarded_main() {
  local common main
  common="$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
  main="$(cd "$common/.." 2>/dev/null && pwd -P)" || return 1
  grep -qs '^### Worktrees[[:space:]]*$' "$main/AGENTS.md" "$main/CLAUDE.md" || return 1
  printf '%s\n' "$main"
}

# Prints the worktrees folder relative to the Main checkout: the worktrees doc's Folder override, if any.
worktrees_folder() {
  local folder
  folder="$(awk '$0 == "## Folder" { on = 1; next } /^## / { on = 0 } on' "$1/docs/agents/worktrees.md" 2>/dev/null \
    | sed -n 's/^`\(.*\)`$/\1/p' | head -n 1)"
  folder="${folder:-.claude/worktrees}"
  printf '%s\n' "${folder%/}"
}

check_file() {
  local path dir main rel
  path="$(resolve "$1" "$cwd")"
  dir="${path%/*}"
  while [ -n "$dir" ] && [ ! -d "$dir" ]; do dir="${dir%/*}"; done
  for main in "$(guarded_main "$cwd")" "$(guarded_main "${dir:-/}")"; do
    [ -n "$main" ] || continue
    case "$path" in "$main"/*) ;; *) continue ;; esac
    rel="${path#"$main"/}"
    case "$rel" in
      "$(worktrees_folder "$main")"/*|.sdlc/*|docs/architecture-improvements/*) ;;
      *) block "editing $rel" "$main" ;;
    esac
  done
}

# changes_checkout <subcommand> <args...>: whether that git command changes the checkout it runs in.
changes_checkout() {
  local sub="$1" a
  shift
  case "$sub" in
    commit|add|switch|rebase|cherry-pick|revert|am) return 0 ;;
    checkout) [ $# -gt 0 ] ;;
    merge|pull)
      for a in "$@"; do [ "$a" = --ff-only ] && return 1; done
      return 0 ;;
    stash) case "${1:-}" in list|show) return 1 ;; esac; return 0 ;;
    apply)
      for a in "$@"; do case "$a" in --apply) return 0 ;; --check|--stat|--numstat|--summary) return 1 ;; esac; done
      return 0 ;;
    *) return 1 ;;
  esac
}

# check_git <dir> <git arguments...>
check_git() {
  local dir="$1" main
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      -C) dir="$(resolve "${2:-.}" "$dir")"; shift; [ $# -gt 0 ] && shift ;;
      -c|--git-dir|--work-tree|--namespace) shift; [ $# -gt 0 ] && shift ;;
      -*) shift ;;
      *) break ;;
    esac
  done
  [ $# -gt 0 ] && changes_checkout "$@" || return 0
  main="$(guarded_main "$dir")" || return 0
  # A linked worktree has its own git dir; only the Main checkout's git dir is the common dir.
  [ "$(git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null)" = "$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" ] || return 0
  block "git $1" "$main"
}

check_command() {
  local dir="$cwd" seg w
  while IFS= read -r seg; do
    set -f
    read -ra w <<<"$seg"
    set +f
    while [ ${#w[@]} -gt 0 ]; do
      case "${w[0]}" in
        *=*|sudo|env|command|exec|time|nohup) w=("${w[@]:1}") ;;
        *) break ;;
      esac
    done
    [ ${#w[@]} -eq 0 ] && continue
    case "${w[0]}" in
      cd) dir="$(resolve "${w[1]:-$HOME}" "$dir")" ;;
      git|*/git) check_git "$dir" "${w[@]:1}" ;;
    esac
  done < <(perl "$(dirname "$0")/split-commands.pl" <<<"$1")
}

file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)"
[ -n "$file" ] && check_file "$file"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -n "$cmd" ] && check_command "$cmd"
exit 0
