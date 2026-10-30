#!/usr/bin/env bash
# Rules read each git, gh or portless command's own arguments, so commit messages and heredocs never trip them.
# Pushes to main are left to branch protection. Adapted from git-guardrails-claude-code in mattpocock/skills.

PUSH_POLICY="allow"   # "allow": pushes allowed, except force and delete. "none": every push blocked.

here="$(cd "$(dirname "$0")" && pwd)"
input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -z "$cmd" ] && exit 0

block() {
  printf 'BLOCKED by sdlc guardrails (%s).' "$1" >&2
  [ -n "$2" ] && printf ' %s' "$2" >&2
  printf ' Do not retry or work around this: ask the user to run it themselves if it is really needed.\n' >&2
  exit 2
}

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
      done ;;
  esac
}

# npx, pnpm dlx, yarn dlx, npm exec and the like: the package's arguments follow its name.
check_launcher() {
  while [ $# -gt 0 ]; do
    case "$1" in portless|portless@*) shift; check_portless "$@"; return ;; esac
    shift
  done
}

# Blocks API calls that merge a PR, change branch protection or delete a repository.
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
      printf '%s' "$cmd" | grep -Eq 'mergePullRequest|enablePullRequestAutoMerge|(create|update|delete)(RepositoryRuleset|BranchProtectionRule)|deleteRepository' \
        && block 'merging or changing protection through the GraphQL API'
      continue
    fi
    [ "$method" = "GET" ] && continue
    case "$a" in
      */pulls/*/merge|*/pulls/*/auto-merge) block 'merging a PR is for the human' ;;
      */rulesets|*/rulesets/*|*/branches/*/protection|*/branches/*/protection/*) block 'changing branch protection' ;;
    esac
    [ "$method" = "DELETE" ] && case "$a" in repos/*/*/*) ;; repos/*/*) block 'deleting a repository' ;; esac
  done
}

check_gh() {
  case "$1" in
    pr) [ "$2" = "merge" ] && block 'merging a PR is for the human' ;;
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
    npx|bunx|pnpx|pnpm|yarn|npm|bun|*/npx|*/pnpm|*/yarn|*/npm|*/bun) check_launcher "${w[@]:1}" ;;
  esac
done < <(segments)
exit 0
