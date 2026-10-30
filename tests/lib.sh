# Helpers the tests/*.sh scripts source. Each script sets $scratch before using new_repo.

failures=0

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    printf 'ok   %s\n' "$name"
  else
    printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$name" "$expected" "$actual"
    failures=$((failures + 1))
  fi
}

contains() {
  local name="$1" needle="$2" haystack="$3"
  case "$haystack" in
    *"$needle"*) printf 'ok   %s\n' "$name" ;;
    *) printf 'FAIL %s\n  expected to contain: %s\n  actual: %s\n' "$name" "$needle" "$haystack"
       failures=$((failures + 1)) ;;
  esac
}

# A bare origin with one commit on main, cloned as the Main checkout.
new_repo() {
  local name="$1"
  git init -q --bare -b main "$scratch/$name-origin.git"
  git clone -q "$scratch/$name-origin.git" "$scratch/$name" 2>/dev/null
  git -C "$scratch/$name" commit -q --allow-empty -m init
  git -C "$scratch/$name" push -q origin main
  git -C "$scratch/$name" remote set-head origin main
  printf '%s' "$scratch/$name"
}

# Backdates the lock, every file and the last commit so the lock reads as stale.
age_worktree() {
  local dir="$1"
  mkdir -p "$dir/.sdlc"
  printf '%s\nold session\n' "$(( $(date +%s) - 3 * 3600 ))" > "$dir/.sdlc/lock"
  find "$dir" -path "$dir/.git" -prune -o -exec touch -t 202001010000 {} +
  GIT_COMMITTER_DATE="2020-01-01T00:00:00" git -C "$dir" commit -q --allow-empty --amend --no-edit
}

finish_tests() {
  echo
  if [ "$failures" -eq 0 ]; then echo "all passed"; else echo "$failures failed"; exit 1; fi
}
