#!/usr/bin/env bash
# Runs skills/check-sdlc/scripts/check.sh against scratch repos in known states and checks each line's id and status.
# Usage: tests/check-sdlc.sh. Scratch repos go under $TMPDIR; the real Portless install is kept off PATH.
set -u

script="$(cd "$(dirname "$0")/.." && pwd)/skills/check-sdlc/scripts/check.sh"
worktree="$(cd "$(dirname "$0")/.." && pwd)/skills/worktrees/scripts/worktree.sh"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/check-sdlc-test.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
. "$(dirname "$0")/lib.sh"
export PORTLESS_STATE_DIR="$scratch/portless-state"
no_portless_path="/usr/bin:/bin:/usr/sbin:/sbin"
mkdir -p "$scratch/bin" "$PORTLESS_STATE_DIR"

# Portless stays off PATH unless the second argument puts it back.
run() { (cd "$1" && PATH="${2:-$no_portless_path}" bash "$script"); }
status() { printf '%s\n' "$2" | jq -r --arg id "$1" 'select(.id == $id) | .status'; }
detail() { printf '%s\n' "$2" | jq -r --arg id "$1" 'select(.id == $id) | .detail'; }

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

echo "# worktrees folder not ignored yet in the main checkout"
unignored="$(set_up_repo unignored)"
git -C "$unignored" rm -q .gitignore && git -C "$unignored" commit -q -m "drop .gitignore"
git -C "$unignored" worktree add -q -b chore/setup-sdlc "$unignored/.claude/worktrees/setup-sdlc" origin/main
mkdir -p "$unignored/.sdlc" && echo x > "$unignored/.sdlc/lock"
out="$(run "$unignored")"
check "worktrees.gitignore fails" "fail" "$(status worktrees.gitignore "$out")"
check "worktrees.main-clean ignores the worktrees and lock folders" "pass" "$(status worktrees.main-clean "$out")"

echo "# uncommitted change in the main checkout"
echo x > "$noignore/stray.txt"
check "worktrees.main-clean warns" "warn" "$(status worktrees.main-clean "$(run "$noignore")")"

# dev_doc <repo> <proxy mode>: a dev stack doc in the format of skills/dev-stack/CONTRACT.md.
dev_doc() {
  cat > "$1/docs/agents/dev-stack.md" <<EOF
# Dev stack

- Entry point: \`scripts/dev-stack\`
- Strategy: A
- Project: \`app\`
- Health URL: \`/health\`
- Cap: 4
- Portless: 0.15.12
- Proxy: $2

## Safe mode

- \`MAIL_TRANSPORT=console\`: mail goes to the log.

## Browsers

Safari may need one \`portless hosts sync\`.
EOF
}

# A dev stack doc and contract, as setup-sdlc's Dev stack section records them.
add_dev_stack() {
  local repo="$1"
  mkdir -p "$repo/scripts"
  dev_doc "$repo" "HTTP on 1355"
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

echo "# dev stack doc only, HTTPS mode, no contract yet"
pending="$(set_up_repo pending)"
dev_doc "$pending" "HTTPS on 443"
printf '\n### Dev stack\n\nSee `docs/agents/dev-stack.md`.\n' >> "$pending/AGENTS.md"
git -C "$pending" add -A && git -C "$pending" commit -q -m "dev stack doc"
out="$(run "$pending" "$scratch/bin:$no_portless_path")"
check "devstack.script fails" "fail" "$(status devstack.script "$out")"
check "portless.proxy reads the doc's mode" "No proxy running; scripts/dev-stack up starts it in the recorded mode, HTTPS on 443." "$(detail portless.proxy "$out")"
check "portless.ca fails in HTTPS mode without a trusted CA" "fail" "$(status portless.ca "$out")"
check "portless.stale-routes reads the doc's project" "Aliases for worktrees that no longer exist: live.app gone.app" "$(detail portless.stale-routes "$out")"

echo "# contract out of step with the doc"
sed -i.bak 's/^PROXY_PORT=1355$/PROXY_PORT=443/' "$stack/scripts/dev-stack" && rm "$stack/scripts/dev-stack.bak"
out="$(run "$stack" "$scratch/bin:$no_portless_path")"
check "devstack.script warns" "warn" "$(status devstack.script "$out")"
contains "names the mismatch" "PROXY_PORT=443" "$(detail devstack.script "$out")"

finish_tests
