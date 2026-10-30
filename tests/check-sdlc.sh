#!/usr/bin/env bash
# Runs skills/check-sdlc/scripts/check.sh against scratch repos in known states and checks each line's id and status.
# Usage: tests/check-sdlc.sh. Scratch repos go under $TMPDIR; the real Portless install is kept off PATH.
set -u

script="$(cd "$(dirname "$0")/.." && pwd)/skills/check-sdlc/scripts/check.sh"
worktree="$(cd "$(dirname "$0")/.." && pwd)/skills/worktrees/scripts/worktree.sh"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/check-sdlc-test.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
failures=0

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export PORTLESS_STATE_DIR="$scratch/portless-state"
no_portless_path="/usr/bin:/bin:/usr/sbin:/sbin"
mkdir -p "$scratch/bin" "$PORTLESS_STATE_DIR"

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

# run <dir> [PATH]: the script's output from inside <dir>.
run() { (cd "$1" && PATH="${2:-$no_portless_path}" bash "$script"); }
status() { printf '%s\n' "$2" | jq -r --arg id "$1" 'select(.id == $id) | .status'; }
detail() { printf '%s\n' "$2" | jq -r --arg id "$1" 'select(.id == $id) | .detail'; }

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

# A repo with everything setup-sdlc writes for a repo with no app, on a local tracker.
set_up_repo() {
  local repo
  repo="$(new_repo "$1")"
  mkdir -p "$repo/docs/agents"
  cat > "$repo/AGENTS.md" <<'EOF'
## Agent skills

### Issue tracker

Local markdown under `.scratch/`. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context. See `docs/agents/domain.md`.

### Code comments

Load the `code-comments` skill before writing or editing any comment.

### Worktrees

Never edit files or commit in the main checkout.
EOF
  printf '@AGENTS.md\n' > "$repo/CLAUDE.md"
  printf '# Issue tracker: Local Markdown\n\nIssues live in `.scratch/`.\n' > "$repo/docs/agents/issue-tracker.md"
  printf '# Domain Docs\n' > "$repo/docs/agents/domain.md"
  printf '# Worktrees\n' > "$repo/docs/agents/worktrees.md"
  printf '.claude/worktrees/\n.sdlc/\n' > "$repo/.gitignore"
  git -C "$repo" add -A && git -C "$repo" commit -q -m setup && git -C "$repo" push -q origin main
  printf '%s' "$repo"
}

# Backdates the lock, every file and the last commit so the lock reads as stale.
age_worktree() {
  local dir="$1"
  mkdir -p "$dir/.sdlc"
  printf '%s\nold session\n' "$(( $(date +%s) - 3 * 3600 ))" > "$dir/.sdlc/lock"
  find "$dir" -path "$dir/.git" -prune -o -exec touch -t 202001010000 {} +
  GIT_COMMITTER_DATE="2020-01-01T00:00:00" git -C "$dir" commit -q --allow-empty --amend --no-edit
}

echo "# no setup"
bare="$(new_repo bare)"
out="$(run "$bare")"
check "one line" "1" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
check "setup.present" "fail" "$(status setup.present "$out")"

echo "# complete setup"
full="$(set_up_repo full)"
before="$(git -C "$full" status --porcelain; git -C "$full" for-each-ref; git -C "$full" worktree list --porcelain)"
out="$(run "$full")"
check "every line is JSON with id, status, detail" "0" "$(printf '%s\n' "$out" | jq -e 'has("id") and has("status") and has("detail")' >/dev/null; echo $?)"
check "nothing fails or warns" "" "$(printf '%s\n' "$out" | jq -r 'select(.status == "fail" or .status == "warn") | .id')"
for id in setup.present agent.jq agent.perl instructions.agents-block instructions.claude-import instructions.code-comments \
  instructions.worktrees-rule tracker.doc domain.doc worktrees.gitignore worktrees.doc worktrees.merged worktrees.stale-locks \
  worktrees.main-clean; do
  check "$id passes" "pass" "$(status "$id" "$out")"
done
for id in ci.workflow portless.installed portless.version portless.stale-routes devstack.doc stacks.cap; do
  check "$id skips" "skip" "$(status "$id" "$out")"
done
after="$(git -C "$full" status --porcelain; git -C "$full" for-each-ref; git -C "$full" worktree list --porcelain)"
check "changes nothing" "$before" "$after"

echo "# deleted domain doc"
nodomain="$(set_up_repo nodomain)"
git -C "$nodomain" rm -q docs/agents/domain.md && git -C "$nodomain" commit -q -m drop
out="$(run "$nodomain")"
check "domain.doc fails" "fail" "$(status domain.doc "$out")"
check "only domain.doc fails" "domain.doc" "$(printf '%s\n' "$out" | jq -r 'select(.status == "fail" or .status == "warn") | .id')"

echo "# merged worktree"
merged="$(set_up_repo merged)"
git -C "$merged" worktree add -q -b feat/done "$merged/.claude/worktrees/done" origin/main
open="$(cd "$merged" && bash "$worktree" create feat/open 2>/dev/null | tail -n 1)"
git -C "$open" commit -q --allow-empty -m wip
out="$(run "$merged")"
check "worktrees.merged warns" "warn" "$(status worktrees.merged "$out")"
contains "names the merged worktree" "done (feat/done)" "$(detail worktrees.merged "$out")"
check "leaves the open worktree out" "" "$(detail worktrees.merged "$out" | grep -o 'open')"
check "from inside a worktree too" "warn" "$(status worktrees.merged "$(run "$open")")"

echo "# stale lock"
age_worktree "$open"
out="$(run "$merged")"
check "worktrees.stale-locks warns" "warn" "$(status worktrees.stale-locks "$out")"
contains "names the holder" "open (old session" "$(detail worktrees.stale-locks "$out")"

echo "# missing gitignore entry"
noignore="$(set_up_repo noignore)"
printf '.claude/worktrees/\n' > "$noignore/.gitignore"
git -C "$noignore" commit -q -am "drop .sdlc"
out="$(run "$noignore")"
check "worktrees.gitignore fails" "fail" "$(status worktrees.gitignore "$out")"
check "names the entry" "Missing from .gitignore: .sdlc/" "$(detail worktrees.gitignore "$out")"

echo "# uncommitted change in the main checkout"
echo x > "$noignore/stray.txt"
check "worktrees.main-clean warns" "warn" "$(status worktrees.main-clean "$(run "$noignore")")"

# A dev stack doc and contract, as setup-sdlc's Dev stack section records them.
add_dev_stack() {
  local repo="$1"
  mkdir -p "$repo/scripts"
  printf '# Dev stack\n\n- Portless version: 0.15.12, proxy mode HTTP on 1355.\n- Cap: 4\n' > "$repo/docs/agents/dev-stack.md"
  printf '\n### Dev stack\n\nSee `docs/agents/dev-stack.md`.\n' >> "$repo/AGENTS.md"
  cat > "$repo/scripts/dev-stack" <<'EOF'
#!/bin/sh
PROJECT="app"
PROXY_PORT=1355
PROXY_TLS=0
case "$1" in
  url) echo "http://app.localhost:1355" ;;
  status) echo stopped; exit 3 ;;
esac
EOF
  chmod +x "$repo/scripts/dev-stack"
  git -C "$repo" add -A && git -C "$repo" commit -q -m "dev stack"
}

echo "# dev stack, Portless absent"
stack="$(set_up_repo stack)"
add_dev_stack "$stack"
out="$(run "$stack")"
check "instructions.dev-stack-pointer passes" "pass" "$(status instructions.dev-stack-pointer "$out")"
check "devstack.script passes" "pass" "$(status devstack.script "$out")"
check "portless.installed fails" "fail" "$(status portless.installed "$out")"
for id in portless.version portless.proxy portless.doctor portless.ca portless.stale-routes devstack.url devstack.status; do
  check "$id skips" "skip" "$(status "$id" "$out")"
done

echo "# dev stack, Portless present"
cat > "$scratch/bin/portless" <<EOF
#!/bin/sh
echo "\$*" >> "$scratch/portless-calls"
case "\$1" in
  --version) echo 0.15.11 ;;
  doctor) echo "ok    Proxy is responding on port 1355."; echo "Summary: 0 failures, 0 warnings." ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$scratch/bin/portless"
live="$(cd "$stack" && bash "$worktree" create feat/live 2>/dev/null | tail -n 1)"
printf '[{"hostname":"live.app.localhost","port":4001,"pid":0},{"hostname":"gone.app.localhost","port":4002,"pid":0},{"hostname":"app.localhost","port":4003,"pid":0},{"hostname":"gone.other.localhost","port":4004,"pid":0}]' > "$PORTLESS_STATE_DIR/routes.json"
printf '1\n' > "$PORTLESS_STATE_DIR/proxy.port"
out="$(run "$stack" "$scratch/bin:$no_portless_path")"
check "portless.installed passes" "pass" "$(status portless.installed "$out")"
check "portless.version warns on a mismatch" "Installed 0.15.11; the dev stack doc pins 0.15.12." "$(detail portless.version "$out")"
check "portless.proxy warns when it isn't running" "warn" "$(status portless.proxy "$out")"
check "portless.doctor passes" "pass" "$(status portless.doctor "$out")"
check "portless.ca skips in HTTP mode" "skip" "$(status portless.ca "$out")"
check "portless.stale-routes names only the gone worktree" "Aliases for worktrees that no longer exist: gone.app" "$(detail portless.stale-routes "$out")"
check "devstack.url passes" "pass" "$(status devstack.url "$out")"
check "devstack.status passes" "pass" "$(status devstack.status "$out")"
check "stacks.cap passes" "pass" "$(status stacks.cap "$out")"
check "only read-only Portless calls" "--version doctor" "$(sort -u "$scratch/portless-calls" | tr '\n' ' ' | sed 's/ $//')"

echo
if [ "$failures" -eq 0 ]; then echo "all passed"; else echo "$failures failed"; exit 1; fi
