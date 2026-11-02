#!/usr/bin/env bash
# Rules read each git, gh, portless or emulate command's own arguments, so commit messages and heredocs never trip them.
# Pushes to main are left to branch protection. Adapted from git-guardrails-claude-code in mattpocock/skills.

PUSH_POLICY="allow"   # "allow": pushes allowed, except force and delete. "none": every push blocked.
MERGE_POLICY="block"  # "block": merging a PR is for the human. "allow": a repo whose docs/agents/merge.md has a `Merge policy: allow` line lets agents merge.

here="$(cd "$(dirname "$0")" && pwd)"
input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
[ -z "$cmd" ] && exit 0

block() {
  printf 'BLOCKED by sdlc guardrails (%s).' "$1" >&2
  [ -n "$2" ] && printf ' %s' "$2" >&2
  printf ' Do not retry or work around this: ask the user to run it themselves if it is really needed.\n' >&2
  exit 2
}

# Branch protection stays the gate, so the opt-in is the only thing checked: no permission lookup.
merge_allowed() {
  local top
  [ "$MERGE_POLICY" = "allow" ] && return 0
  top="$(git -C "${cwd:-.}" rev-parse --show-toplevel 2>/dev/null)" || return 1
  grep -Eqi '^[[:space:]]*Merge policy:[[:space:]]*allow[[:space:]]*$' "$top/docs/agents/merge.md" 2>/dev/null
}

block_merge() { merge_allowed || block 'merging a PR is for the human'; }

segments() { perl "$here/split-commands.pl" <<<"$cmd"; }

check_push() {
  [ "$PUSH_POLICY" = "none" ] && block 'git push is disabled'
  local a
  for a in "$@"; do
    case "$a" in
      --force|--force=*|--force-with-lease|--force-with-lease=*|--force-if-includes) block 'force push' ;;
      --mirror) block 'mirror push' ;;
      --delete|--prune) block 'deleting remote branches' ;;
      --no-verify) block 'skipping the pre-push hook' ;;
      --*) ;;
      -*[fd]*) block 'force or delete push' ;;
      +*) block 'force push via +refspec' ;;
      :*) block 'deleting a remote branch' ;;
    esac
  done
}

check_git() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -c) case "$2" in core.hooksPath*|core.hookspath*) block 'disabling git hooks' ;; esac
          shift; [ $# -gt 0 ] && shift ;;
      -C|--git-dir|--work-tree|--namespace) shift; [ $# -gt 0 ] && shift ;;
      -*) shift ;;
      *) break ;;
    esac
  done
  local sub="$1" a force=0 delete=0
  [ $# -gt 0 ] && shift
  case "$sub" in
    push) check_push "$@" ;;
    commit)
      for a in "$@"; do
        case "$a" in
          --no-verify) block 'skipping the pre-commit hook' ;;
          --*) ;;
          -*n*) block 'skipping the pre-commit hook' ;;
        esac
      done ;;
    reset)
      for a in "$@"; do [ "$a" = "--hard" ] && block 'git reset --hard'; done ;;
    clean)
      for a in "$@"; do
        case "$a" in --force) block 'git clean -f' ;; --*) ;; -*f*) block 'git clean -f' ;; esac
      done ;;
    branch)
      for a in "$@"; do
        case "$a" in
          --delete) delete=1 ;;
          --force) force=1 ;;
          --*) ;;
          -*D*) block 'git branch -D' ;;
          -*) case "$a" in *d*) delete=1 ;; esac; case "$a" in *f*) force=1 ;; esac ;;
        esac
      done
      [ "$delete$force" = "11" ] && block 'git branch -D' ;;
    checkout|restore)
      for a in "$@"; do [ "$a" = "." ] && block 'discarding all working-tree changes'; done ;;
    worktree)
      [ "$1" = "remove" ] || return 0
      local why='It discards the uncommitted changes in that worktree. Commit or keep what is there, then remove it without force.'
      for a in "$@"; do
        case "$a" in
          --force) block 'git worktree remove --force' "$why" ;;
          --*) ;;
          -*f*) block 'git worktree remove -f' "$why" ;;
        esac
      done ;;
  esac
}

# The subcommand is the first known one, not the first word, so an option's value can't hide it.
check_portless() {
  local shared="The proxy and its routes are shared by every worktree's dev stack on this machine. Stop only your own stack, through the repo's dev stack contract (down or destroy)."
  local sub="" a
  while [ $# -gt 0 ]; do
    a="$1"; shift
    case "$a" in run|proxy|mcp|service|get|alias|list|doctor|trust|clean|prune|hosts) sub="$a"; break ;; esac
  done
  case "$sub" in
    clean) block 'portless clean' "$shared" ;;
    proxy|hosts|service)
      for a in "$@"; do
        case "$sub $a" in
          'proxy stop'|'hosts clean'|'service uninstall') block "portless $sub $a" "$shared" ;;
        esac
      done ;;
    run)
      for a in "$@"; do
        [ "$a" = "--force" ] && block 'portless run --force' "It takes over a route another worktree may own. Start your stack through the repo's dev stack contract, which names the route after this worktree."
      done
      # The wrapped command, direct or through a launcher, starts at any word naming emulate.
      while [ $# -gt 0 ]; do
        a="$1"; shift
        case "$a" in emulate|emulate@*|*/emulate) check_emulate "$@"; return ;; esac
      done ;;
  esac
}

check_emulate() {
  local a
  for a in "$@"; do
    case "$a" in
      --portless|--portless=*) block "emulate --portless" "It registers machine-wide routes with --force, which override another worktree's. Start Emulators through the repo's dev stack contract, which names their routes after this worktree." ;;
    esac
  done
}

# npx, pnpm dlx, yarn dlx, npm exec and the like: the package's arguments follow its name.
check_launcher() {
  while [ $# -gt 0 ]; do
    case "$1" in
      portless|portless@*) shift; check_portless "$@"; return ;;
      emulate|emulate@*) shift; check_emulate "$@"; return ;;
    esac
    shift
  done
}

# Blocks API calls that merge a PR (unless the repo opts in), change branch protection or delete a repository.
check_gh_api() {
  local a prev="" method="" fields=0 paths=""
  for a in "$@"; do
    case "$prev" in
      -X|--method) method="$a" ;;
      -f|-F|--field|--raw-field|--input) fields=1 ;;
      -H|--header|-q|--jq|-t|--template|--hostname|-p|--preview|--cache) ;;
      *) case "$a" in
           --method=*) method="${a#*=}" ;;
           -X?*) method="${a#-X}" ;;
           -f?*|-F?*|--field=*|--raw-field=*|--input=*) fields=1 ;;
           -*) ;;
           *) paths="$paths ${a#/}" ;;
         esac ;;
    esac
    prev="$a"
  done
  method="$(printf '%s' "$method" | tr '[:lower:]' '[:upper:]')"
  [ -z "$method" ] && { [ "$fields" = 1 ] && method=POST || method=GET; }
  for a in $paths; do
    if [ "$a" = "graphql" ]; then
      printf '%s' "$cmd" | grep -Eq '(create|update|delete)(RepositoryRuleset|BranchProtectionRule)|deleteRepository' \
        && block 'changing protection or deleting a repository through the GraphQL API'
      printf '%s' "$cmd" | grep -Eq 'mergePullRequest|enablePullRequestAutoMerge' && block_merge
      continue
    fi
    [ "$method" = "GET" ] && continue
    case "$a" in
      */pulls/*/merge|*/pulls/*/auto-merge) block_merge ;;
      */rulesets|*/rulesets/*|*/branches/*/protection|*/branches/*/protection/*) block 'changing branch protection' ;;
    esac
    [ "$method" = "DELETE" ] && case "$a" in repos/*/*/*) ;; repos/*/*) block 'deleting a repository' ;; esac
  done
}

check_gh() {
  case "$1" in
    pr) [ "$2" = "merge" ] && block_merge ;;
    repo)
      [ "$2" = "delete" ] && block 'deleting a repository'
      if [ "$2" = "edit" ]; then
        local a
        for a in "$@"; do case "$a" in --visibility|--visibility=*) block 'changing repository visibility' ;; esac; done
      fi ;;
    api) shift; check_gh_api "$@" ;;
  esac
}

while IFS= read -r seg; do
  set -f
  read -ra w <<<"$seg"
  set +f
  # Skip environment assignments and wrappers in front of the command.
  while [ ${#w[@]} -gt 0 ]; do
    case "${w[0]}" in
      *=*|sudo|env|command|exec|time|nohup) w=("${w[@]:1}") ;;
      *) break ;;
    esac
  done
  [ ${#w[@]} -eq 0 ] && continue
  case "${w[0]}" in
    git|*/git) check_git "${w[@]:1}" ;;
    gh|*/gh) check_gh "${w[@]:1}" ;;
    portless|*/portless) check_portless "${w[@]:1}" ;;
    emulate|*/emulate) check_emulate "${w[@]:1}" ;;
    npx|bunx|pnpx|pnpm|yarn|npm|bun|*/npx|*/pnpm|*/yarn|*/npm|*/bun) check_launcher "${w[@]:1}" ;;
  esac
done < <(segments)
exit 0
