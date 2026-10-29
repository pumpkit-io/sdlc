#!/usr/bin/env bash
# sdlc git guardrails: PreToolUse hook for the Bash tool.
# Exit 0 lets the command run. Exit 2 blocks it, and stderr is shown to the agent.
# Rules check the arguments of each git or gh command, so text in commit messages, PR bodies,
# heredocs and other chained commands never trips them. Pushes to main are left to each repo's
# branch protection. Adapted from the git-guardrails-claude-code skill in mattpocock/skills.
# Requires jq and perl.

PUSH_POLICY="allow"   # "allow": pushes allowed, except force and delete. "none": every push blocked.

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -z "$cmd" ] && exit 0

block() {
  printf 'BLOCKED by sdlc guardrails (%s). Do not retry or work around this: ask the user to run it themselves if it is really needed.\n' "$1" >&2
  exit 2
}

# Prints one simple command per line. Heredoc bodies are dropped unless a shell reads them,
# `sh -c` and `eval` arguments become commands of their own, and a quoted string stays only
# when it is a single word (so `"main"` survives and a commit message doesn't).
segments() {
  perl -e '
    my $s = do { local $/; <STDIN> };
    my (@out, @pending);
    for my $line (split /\n/, $s, -1) {
      if (@pending) {
        my ($term, $keep) = @{ $pending[0] };
        if ($line =~ /^\s*\Q$term\E\s*$/) { shift @pending; next }
        push @out, $line if $keep;
        next;
      }
      push @out, $line;
      while ($line =~ /(?<!<)<<(?!<)-?\s*([\x27"]?)([A-Za-z_][\w-]*)\1/g) {
        my $before = substr($line, 0, $-[0]);
        push @pending, [$2, $before =~ /(?:^|[\s;&|(])(?:ba|z|da)?sh(?:\s+-\S+)*\s*$/ ? 1 : 0];
      }
    }
    $s = join "\n", @out;
    my @lifted;
    while ($s =~ /(?:\b(?:ba|z|da)?sh\s+-c|\beval)\s+(\x27[^\x27]*\x27|"(?:[^"\\]|\\.)*")/g) {
      push @lifted, substr($1, 1, -1);
    }
    $s = join "\n", $s, @lifted;
    $s =~ s{\x27([^\x27]*)\x27|"((?:[^"\\]|\\.)*)"}{
      my $q = defined $1 ? $1 : $2;
      $q =~ /^[^\s;&|()<>`\$]*$/ ? $q : " _ ";
    }ge;
    for (split /[;&|\n()`]/, $s) { s/^\s+|\s+$//g; print "$_\n" if length }
  ' <<<"$cmd"
}

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
  esac
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
  esac
done < <(segments)
exit 0
