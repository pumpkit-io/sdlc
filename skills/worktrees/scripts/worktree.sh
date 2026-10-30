#!/usr/bin/env bash
# The mechanical half of the worktrees skill. See ../SKILL.md for when to run each command.
#
#   worktree.sh main                       print the Main checkout
#   worktree.sh slug <branch>              print the branch's Slug
#   worktree.sh create <branch> [<base>]   find or add the branch's worktree; last stdout line is its path
#   worktree.sh lock [--take-over] <worktree> <description>
#   worktree.sh release <worktree>
#   worktree.sh list                       tab-separated: slug, branch, ahead, behind, lock, lock age, dev stack
#   worktree.sh finish <worktree> [--pr-open | --merged-into <branch>]
#   worktree.sh sweep
#
# Exit codes: 0 done, 1 refused (reason on stderr), 2 usage, 3 lock busy, 4 lock stale, 5 unmerged and unpushed.
set -u

stale_minutes=120
doc_path=docs/agents/worktrees.md
gitignore_message="chore: ignore worktrees and session locks"

say() { printf '%s\n' "$*" >&2; }
die() { say "$*"; exit 1; }
usage() { sed -n '4,13p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

main_checkout() {
  local common
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || die "Not inside a git repository."
  (cd "$common/.." && pwd -P)
}

slug() {
  local s="${1##*/}"
  s="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9-]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//')"
  s="${s:0:63}"
  printf '%s\n' "${s%-}"
}

# Prints the body of one "## <heading>" section of the worktrees doc.
doc_section() {
  local doc="$1" heading="$2"
  [ -f "$doc" ] || return 0
  awk -v h="## $heading" '$0 == h { on = 1; next } /^## / { on = 0 } on' "$doc"
}

worktrees_folder() {
  local main="$1" folder
  folder="$(doc_section "$main/$doc_path" Folder | sed -n 's/^`\(.*\)`$/\1/p' | head -n 1)"
  printf '%s\n' "$main/${folder:-.claude/worktrees}"
}

default_branch() {
  local ref
  ref="$(git -C "$1" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)" || die "origin/HEAD is not set: run 'git remote set-head origin --auto' in the main checkout."
  printf '%s\n' "${ref#origin/}"
}

# Prints "<path> <branch>" for every linked worktree; detached ones have an empty branch.
# The main checkout is always the first entry, so it is skipped by position, not by path.
linked_worktrees() {
  git -C "$1" worktree list --porcelain | awk '
    /^worktree / { n++; path = substr($0, 10); branch = "" }
    /^branch / { branch = substr($0, 19) }
    /^$/ { if (n > 1 && path != "") print path "\t" branch; path = "" }
    END { if (n > 1 && path != "") print path "\t" branch }'
}

# When the lock was taken: its first line, or the file's mtime when a half-written or hand-edited lock lacks one.
lock_taken() {
  local taken
  taken="$(sed -n 1p "$1/.sdlc/lock" 2>/dev/null)"
  case "$taken" in
    ''|*[!0-9]*) stat -f %m "$1/.sdlc/lock" 2>/dev/null || stat -c %Y "$1/.sdlc/lock" 2>/dev/null || date +%s ;;
    *) printf '%s\n' "$taken" ;;
  esac
}

# Fresh while any of the lock, the last commit or a file change is under two hours old.
lock_state() {
  local wt="$1" now taken last_commit
  [ -f "$wt/.sdlc/lock" ] || { echo free; return; }
  now="$(date +%s)"
  taken="$(lock_taken "$wt")"
  last_commit="$(git -C "$wt" log -1 --format=%ct 2>/dev/null || echo 0)"
  if [ $(( (now - taken) / 60 )) -lt "$stale_minutes" ] || [ $(( (now - last_commit) / 60 )) -lt "$stale_minutes" ] ||
     [ -n "$(find "$wt" \( -path "$wt/.git" -o -path "$wt/.sdlc" \) -prune -o -mmin "-$stale_minutes" -print 2>/dev/null | head -n 1)" ]; then
    echo fresh
  else
    echo stale
  fi
}

lock_holder() { sed -n 2p "$1/.sdlc/lock"; }
lock_age() { echo "$(( ($(date +%s) - $(lock_taken "$1")) / 60 ))m"; }

# Present from worktree add until bootstrap succeeds, so a rerun of create retries it.
# It lives in the worktree's git dir, out of the working tree and its status.
bootstrap_marker() { printf '%s/sdlc-bootstrap-pending\n' "$(git -C "$1" rev-parse --absolute-git-dir)"; }

bootstrap() {
  local main="$1" wt="$2" doc="$2/$doc_path" file install
  if [ -f "$doc" ]; then
    doc_section "$doc" Copy | sed -n 's/^- `\(.*\)`$/\1/p' | while IFS= read -r file; do
      if [ -e "$main/$file" ] && [ ! -e "$wt/$file" ]; then
        mkdir -p "$(dirname "$wt/$file")" && cp -R "$main/$file" "$wt/$file" && say "Copied $file."
      fi
    done
    install="$(doc_section "$doc" Install | awk '/^```/ { on = !on; next } on')"
    if [ -n "$install" ]; then
      say "Running the install command."
      (cd "$wt" && sh -c "$install") >&2 || die "The install command failed in $wt."
    fi
  else
    say "No $doc_path: copied nothing and ran no install."
  fi

  local folder rel missing=""
  folder="$(worktrees_folder "$main")"
  rel="${folder#"$main"/}"
  git -C "$wt" check-ignore -q "$rel/probe" || missing="$missing$rel/"$'\n'
  git -C "$wt" check-ignore -q .sdlc/lock || missing="$missing.sdlc/"$'\n'
  if [ -n "$missing" ]; then
    [ -s "$wt/.gitignore" ] && [ -n "$(tail -c 1 "$wt/.gitignore")" ] && echo >> "$wt/.gitignore"
    printf '%s' "$missing" >> "$wt/.gitignore"
    git -C "$wt" add .gitignore && git -C "$wt" commit -q -m "$gitignore_message" .gitignore && say "Committed the missing .gitignore entries." ||
      die "Could not commit the .gitignore entries in $wt."
  fi
  rm -f "$(bootstrap_marker "$wt")"
}

cmd_create() {
  [ $# -ge 1 ] || usage
  local branch="$1" base="${2:-}" main folder s path line other_path other_branch
  main="$(main_checkout)"
  folder="$(worktrees_folder "$main")"
  s="$(slug "$branch")"
  [ -n "$s" ] || die "Branch $branch gives an empty slug."

  [ "$(git -C "$main" branch --show-current)" = "$branch" ] &&
    die "Branch $branch is checked out in the main checkout ($main). Switch the main checkout to another branch, or name a different branch; the main checkout is left as it is."

  while IFS=$'\t' read -r other_path other_branch; do
    [ -n "$other_path" ] || continue
    if [ "$other_branch" = "$branch" ]; then
      say "Worktree for $branch already exists."
      if [ -f "$(bootstrap_marker "$other_path")" ]; then
        say "Its bootstrap did not finish; running it again."
        bootstrap "$main" "$other_path"
      fi
      printf '%s\n' "$other_path"
      return 0
    fi
    [ -n "$other_branch" ] && [ "$(slug "$other_branch")" = "$s" ] &&
      die "Slug $s is taken by $other_branch at $other_path. Pick a branch name with a different last segment."
  done < <(linked_worktrees "$main")

  path="$folder/$s"
  [ -e "$path" ] && die "$path already exists and is not a worktree of $branch."
  mkdir -p "$folder"

  git -C "$main" fetch -q origin || die "git fetch origin failed."
  if git -C "$main" show-ref -q --verify "refs/heads/$branch"; then
    git -C "$main" worktree add -q "$path" "$branch" || die "git worktree add failed."
  elif git -C "$main" show-ref -q --verify "refs/remotes/origin/$branch"; then
    git -C "$main" worktree add -q --track -b "$branch" "$path" "origin/$branch" || die "git worktree add failed."
  else
    base="${base:-origin/$(default_branch "$main")}"
    git -C "$main" worktree add -q --no-track -b "$branch" "$path" "$base" || die "git worktree add failed."
  fi
  say "Created $path on $branch."
  touch "$(bootstrap_marker "$path")"
  bootstrap "$main" "$path"
  printf '%s\n' "$path"
}

cmd_lock() {
  local take_over=""
  [ "${1:-}" = --take-over ] && { take_over=1; shift; }
  [ $# -eq 2 ] || usage
  local wt description="$2" main
  wt="$(cd "$1" 2>/dev/null && pwd -P)" || die "$1 does not exist."
  main="$(cd "$wt" && main_checkout)"
  [ "$wt" = "$main" ] && die "$wt is the main checkout: lock a worktree instead."
  local lock="$wt/.sdlc/lock"
  mkdir -p "$wt/.sdlc"
  # noclobber makes taking a free lock atomic: of two sessions racing, one write fails.
  if [ -z "$take_over" ] && (set -C; printf '%s\n%s\n' "$(date +%s)" "$description" > "$lock") 2>/dev/null; then
    return 0
  fi
  if [ -z "$take_over" ] && [ "$(lock_holder "$wt")" != "$description" ]; then
    case "$(lock_state "$wt")" in
      stale) say "Stale: locked by $(lock_holder "$wt"), $(lock_age "$wt") ago, with no file change or commit in the last two hours."; exit 4 ;;
      *) say "Busy: locked by $(lock_holder "$wt"), $(lock_age "$wt") ago."; exit 3 ;;
    esac
  fi
  printf '%s\n%s\n' "$(date +%s)" "$description" > "$lock.$$" && mv -f "$lock.$$" "$lock"
}

cmd_release() {
  [ $# -eq 1 ] || usage
  rm -f "$1/.sdlc/lock"
}

stack_status() {
  local wt="$1"
  if [ -x "$wt/scripts/dev-stack" ]; then
    (cd "$wt" && scripts/dev-stack status 2>/dev/null | tail -n 1) || true
  else
    echo -
  fi
}

cmd_list() {
  local main default wt branch counts lock age
  main="$(main_checkout)"
  default="$(default_branch "$main")"
  while IFS=$'\t' read -r wt branch; do
    [ -n "$wt" ] || continue
    counts="$(git -C "$wt" rev-list --left-right --count "origin/$default...HEAD" 2>/dev/null || printf '?\t?')"
    if [ -f "$wt/.sdlc/lock" ]; then
      lock="$(lock_holder "$wt")"
      [ "$(lock_state "$wt")" = stale ] && lock="$lock (stale)"
      age="$(lock_age "$wt")"
    else
      lock=-; age=-
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(basename "$wt")" "${branch:-(detached)}" \
      "$(printf '%s' "$counts" | cut -f 2)" "$(printf '%s' "$counts" | cut -f 1)" "$lock" "$age" "$(stack_status "$wt")"
  done < <(linked_worktrees "$main")
}

# Finishes one worktree. Exit 1, 3 and 5 refuse with the reason on stderr; sweep reports the same reasons.
finish_one() {
  local wt="$1" pr_open="$2" into="${3:-}" main default branch here dirty
  main="$(cd "$wt" && main_checkout)"
  [ "$wt" = "$main" ] && { say "$wt is the main checkout."; return 1; }
  here="$(pwd -P)"
  case "$here/" in
    "$wt"/*) say "Leave $wt first: switch the session to the main checkout or another worktree, then finish it."; return 1 ;;
  esac
  dirty="$(git -C "$wt" status --porcelain)"
  [ -n "$dirty" ] && { say "uncommitted changes:"; say "$dirty"; return 1; }
  if [ -f "$wt/.sdlc/lock" ]; then
    say "locked by $(lock_holder "$wt"), $(lock_age "$wt") ago ($(lock_state "$wt")). Release the lock first."
    return 3
  fi

  default="$(default_branch "$main")"
  branch="$(git -C "$wt" branch --show-current)"
  local merged="" pushed="" target="${into:-origin/$default}"
  git -C "$wt" merge-base --is-ancestor HEAD "$target" && merged=1
  git -C "$wt" rev-parse -q --verify '@{upstream}' >/dev/null 2>&1 &&
    git -C "$wt" merge-base --is-ancestor HEAD '@{upstream}' && pushed=1
  if [ -z "$merged" ] && [ -z "$pushed" ] && [ -z "$pr_open" ]; then
    say "not merged into $target and not pushed. Finish it with --pr-open only if an open PR covers $branch."
    return 5
  fi

  if [ -x "$wt/scripts/dev-stack" ]; then
    (cd "$wt" && scripts/dev-stack destroy) >&2 || { say "scripts/dev-stack destroy failed; the worktree is kept."; return 1; }
  fi
  git -C "$main" worktree remove "$wt" || { say "git worktree remove failed."; return 1; }
  if [ -n "$branch" ]; then
    # git branch -d checks the upstream when one is set, so point it at the branch it was merged into.
    [ -n "$merged" ] && git -C "$main" branch -q --set-upstream-to="$target" "$branch" >/dev/null 2>&1
    if git -C "$main" branch -q -d "$branch" 2>/dev/null; then
      say "Removed $wt and deleted $branch."
    else
      say "Removed $wt. Kept $branch: git branch -d refuses it until it is merged or pushed."
    fi
  fi
  git -C "$main" worktree prune
}

cmd_finish() {
  [ $# -ge 1 ] || usage
  local wt pr_open="" into=""
  wt="$(cd "$1" 2>/dev/null && pwd -P)" || die "$1 does not exist."
  case "${2:-}" in
    --pr-open) pr_open=1 ;;
    --merged-into) [ $# -eq 3 ] || usage; into="$3" ;;
    "") ;;
    *) usage ;;
  esac
  finish_one "$wt" "$pr_open" "$into"
}

cmd_sweep() {
  local main default wt branch reason code
  main="$(main_checkout)"
  default="$(default_branch "$main")"
  git -C "$main" fetch -q origin || die "git fetch origin failed."
  while IFS=$'\t' read -r wt branch; do
    [ -n "$wt" ] || continue
    if ! git -C "$wt" merge-base --is-ancestor HEAD "origin/$default" 2>/dev/null; then
      printf 'Left %s: not merged into origin/%s.\n' "$(basename "$wt")" "$default"
      continue
    fi
    reason="$(finish_one "$wt" "" 2>&1)"; code=$?
    if [ "$code" -eq 0 ]; then
      printf 'Finished %s (%s).\n' "$(basename "$wt")" "$branch"
    else
      printf 'Left %s: %s\n' "$(basename "$wt")" "$(printf '%s' "$reason" | tr '\n' ' ')"
    fi
  done < <(linked_worktrees "$main")
}

case "${1:-}" in
  main) main_checkout ;;
  slug) [ $# -eq 2 ] || usage; slug "$2" ;;
  create) shift; cmd_create "$@" ;;
  lock) shift; cmd_lock "$@" ;;
  release) shift; cmd_release "$@" ;;
  list) cmd_list ;;
  finish) shift; cmd_finish "$@" ;;
  sweep) cmd_sweep ;;
  *) usage ;;
esac
