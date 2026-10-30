#!/usr/bin/env bash
# The mechanical half of check-sdlc. See ../CHECKS.md for what each id means and how to fix it.
#
#   check.sh [<checkout>]
#
# Reads repo files from <checkout> (default: the current top level) and worktrees, locks and the
# main checkout's state from the Main checkout. Prints one JSON line per check: id, status
# (pass, warn, fail, skip) and detail. Changes nothing: no fetch, no Portless command that writes.
set -u

here="$(cd "$(dirname "$0")" && pwd -P)"
worktree_sh="$here/../../worktrees/scripts/worktree.sh"
templates="$here/../../setup-sdlc"
state_dir="${PORTLESS_STATE_DIR:-$HOME/.portless}"

json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/}"
  s="${s//$'\n'/\\n}"
  printf '"%s"' "$s"
}
emit() { printf '{"id":%s,"status":%s,"detail":%s}\n' "$(json "$1")" "$(json "$2")" "$(json "$3")"; }

top="$(cd "${1:-.}" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" ||
  { emit setup.present fail "Not inside a git repository."; exit 0; }
main="$(cd "$top" && bash "$worktree_sh" main 2>/dev/null)" || main="$top"

has_line() { [ -f "$1" ] && grep -qxF "$2" "$1"; }

# The file holding the "## Agent skills" block: AGENTS.md, or CLAUDE.md in setups older than AGENTS.md.
block_file=""
if has_line "$top/AGENTS.md" "## Agent skills"; then
  block_file="$top/AGENTS.md"
elif has_line "$top/CLAUDE.md" "## Agent skills"; then
  block_file="$top/CLAUDE.md"
fi
block() { [ -n "$block_file" ] && awk '$0 == "## Agent skills" { on = 1; next } /^## / { on = 0 } on' "$block_file"; }
block_has() { block | grep -qxF "### $1"; }

if [ -z "$block_file" ] && [ ! -f "$top/docs/agents/issue-tracker.md" ] && [ ! -f "$top/docs/agents/domain.md" ]; then
  emit setup.present fail "No '## Agent skills' block and no docs/agents/: this repo was never set up."
  exit 0
fi
emit setup.present pass "Agent skills block in ${block_file#"$top"/}."

# Agent and plugin

for tool in jq perl; do
  if command -v "$tool" >/dev/null 2>&1; then
    emit "agent.$tool" pass "$(command -v "$tool")"
  else
    emit "agent.$tool" fail "$tool is not on PATH: the Claude Code hooks need it."
  fi
done

# Repo instructions

if has_line "$top/AGENTS.md" "## Agent skills"; then
  emit instructions.agents-block pass "AGENTS.md"
elif [ -n "$block_file" ]; then
  emit instructions.agents-block warn "The block is in CLAUDE.md only, where other agents can't read it."
else
  emit instructions.agents-block fail "No '## Agent skills' block in AGENTS.md."
fi

same_file() { [ "$(ls -diL "$1" | awk '{print $1}')" = "$(ls -diL "$2" | awk '{print $1}')" ]; }

if [ ! -f "$top/AGENTS.md" ]; then
  emit instructions.claude-import skip "No AGENTS.md."
  emit instructions.old-claude-block skip "No AGENTS.md."
elif [ ! -e "$top/CLAUDE.md" ]; then
  emit instructions.claude-import warn "No CLAUDE.md: Claude Code doesn't read AGENTS.md."
  emit instructions.old-claude-block skip "No CLAUDE.md."
elif same_file "$top/CLAUDE.md" "$top/AGENTS.md"; then
  emit instructions.claude-import pass "CLAUDE.md and AGENTS.md are one file."
  emit instructions.old-claude-block pass "One file."
else
  if grep -qx '@AGENTS.md' "$top/CLAUDE.md"; then
    emit instructions.claude-import pass "CLAUDE.md imports AGENTS.md."
  else
    emit instructions.claude-import fail "CLAUDE.md has no @AGENTS.md line."
  fi
  if has_line "$top/CLAUDE.md" "## Agent skills" && has_line "$top/AGENTS.md" "## Agent skills"; then
    emit instructions.old-claude-block warn "CLAUDE.md still holds an '## Agent skills' block from an earlier setup."
  else
    emit instructions.old-claude-block pass "Only AGENTS.md holds the block."
  fi
fi

for pair in "code-comments:Code comments" "worktrees-rule:Worktrees"; do
  if block_has "${pair#*:}"; then
    emit "instructions.${pair%%:*}" pass "### ${pair#*:}"
  else
    emit "instructions.${pair%%:*}" fail "The block has no '### ${pair#*:}' sub-block."
  fi
done

dev_doc="$top/docs/agents/dev-stack.md"
if [ ! -f "$dev_doc" ]; then
  emit instructions.dev-stack-pointer skip "No dev stack doc."
elif block_has "Dev stack"; then
  emit instructions.dev-stack-pointer pass "### Dev stack"
else
  emit instructions.dev-stack-pointer fail "docs/agents/dev-stack.md exists but the block has no '### Dev stack' sub-block."
fi

# Issue tracker

tracker_doc="$top/docs/agents/issue-tracker.md"
if [ -f "$tracker_doc" ] && block_has "Issue tracker"; then
  emit tracker.doc pass "docs/agents/issue-tracker.md"
elif [ -f "$tracker_doc" ]; then
  emit tracker.doc fail "The block has no '### Issue tracker' sub-block."
else
  emit tracker.doc fail "No docs/agents/issue-tracker.md."
fi

tracker_cli=""
if [ -f "$tracker_doc" ]; then
  if grep -q '`gh`\|gh issue' "$tracker_doc"; then tracker_cli=gh; elif grep -q '`glab`\|glab issue' "$tracker_doc"; then tracker_cli=glab; fi
fi
if [ -z "$tracker_cli" ]; then
  emit tracker.cli skip "The tracker needs no CLI."
elif ! command -v "$tracker_cli" >/dev/null 2>&1; then
  emit tracker.cli fail "$tracker_cli is not on PATH."
elif "$tracker_cli" auth status >/dev/null 2>&1; then
  emit tracker.cli pass "$tracker_cli is signed in."
else
  emit tracker.cli fail "$tracker_cli is not signed in."
fi

labels_doc="$top/docs/agents/triage-labels.md"
if block_has "Triage labels" && [ ! -f "$labels_doc" ]; then
  emit tracker.triage-labels fail "The block has '### Triage labels' but docs/agents/triage-labels.md is missing."
elif [ -f "$labels_doc" ] && ! block_has "Triage labels"; then
  emit tracker.triage-labels warn "docs/agents/triage-labels.md exists but the block doesn't point to it."
elif [ -f "$labels_doc" ]; then
  emit tracker.triage-labels pass "docs/agents/triage-labels.md"
else
  emit tracker.triage-labels pass "Default labels."
fi

# Domain docs

if [ -f "$top/docs/agents/domain.md" ] && block_has "Domain docs"; then
  emit domain.doc pass "docs/agents/domain.md"
elif [ -f "$top/docs/agents/domain.md" ]; then
  emit domain.doc fail "The block has no '### Domain docs' sub-block."
else
  emit domain.doc fail "No docs/agents/domain.md."
fi

# Design

if [ ! -f "$top/DESIGN.md" ]; then
  emit design.doc skip "No DESIGN.md."
elif cmp -s "$top/DESIGN.md" "$templates/design.md"; then
  emit design.doc warn "DESIGN.md is still the empty skeleton."
else
  emit design.doc pass "DESIGN.md"
fi

# CI review

workflow="$top/.github/workflows/sdlc-review.yml"
if ! git -C "$top" remote get-url origin 2>/dev/null | grep -q 'github\.com'; then
  for id in ci.workflow ci.template ci.secret; do emit "$id" skip "origin is not on GitHub."; done
elif [ ! -f "$workflow" ]; then
  emit ci.workflow warn "No .github/workflows/sdlc-review.yml."
  emit ci.template skip "No workflow."
  emit ci.secret skip "No workflow."
else
  emit ci.workflow pass ".github/workflows/sdlc-review.yml"
  if cmp -s "$workflow" "$templates/sdlc-review.yml"; then
    emit ci.template pass "Matches the current template."
  else
    emit ci.template warn "Differs from the current template: diff $workflow $templates/sdlc-review.yml"
  fi
  if ! command -v gh >/dev/null 2>&1; then
    emit ci.secret skip "gh is not on PATH."
  elif ! names="$(cd "$top" && gh secret list --json name --jq '.[].name' 2>/dev/null)"; then
    emit ci.secret skip "gh can't list this repo's secrets."
  elif printf '%s\n' "$names" | grep -qx CLAUDE_CODE_OAUTH_TOKEN; then
    emit ci.secret pass "CLAUDE_CODE_OAUTH_TOKEN exists."
  else
    emit ci.secret fail "No CLAUDE_CODE_OAUTH_TOKEN secret."
  fi
fi

# Worktrees

wt_doc="$top/docs/agents/worktrees.md"
doc_section() { [ -f "$1" ] && awk -v h="## $2" '$0 == h { on = 1; next } /^## / { on = 0 } on' "$1"; }
folder="$(doc_section "$wt_doc" Folder | sed -n 's/^`\(.*\)`$/\1/p' | head -n 1)"
folder="${folder:-.claude/worktrees}"

missing=""
git -C "$top" check-ignore -q "$folder/probe" || missing="$missing $folder/"
git -C "$top" check-ignore -q .sdlc/lock || missing="$missing .sdlc/"
if [ -z "$missing" ]; then
  emit worktrees.gitignore pass "$folder/ and .sdlc/ are ignored."
else
  emit worktrees.gitignore fail "Missing from .gitignore:$missing"
fi

if [ ! -f "$wt_doc" ]; then
  emit worktrees.doc warn "No docs/agents/worktrees.md: new worktrees get no files copied and no install."
  emit worktrees.bootstrap skip "No worktrees doc."
else
  emit worktrees.doc pass "docs/agents/worktrees.md"
  absent=""
  while IFS= read -r file; do
    [ -n "$file" ] && [ ! -e "$main/$file" ] && absent="$absent $file"
  done < <(doc_section "$wt_doc" Copy | sed -n 's/^- `\(.*\)`$/\1/p')
  if [ -z "$absent" ]; then
    emit worktrees.bootstrap pass "Every file in Copy exists in the main checkout."
  else
    emit worktrees.bootstrap warn "Listed in Copy but missing from the main checkout:$absent"
  fi
fi

prunable="$(git -C "$main" worktree list --porcelain | awk '/^worktree / { p = substr($0, 10) } /^prunable/ { print p }')"
if [ -z "$prunable" ]; then
  emit worktrees.missing-dirs pass "Every worktree's folder exists."
else
  emit worktrees.missing-dirs warn "Registered but missing on disk: $(printf '%s' "$prunable" | tr '\n' ' ')"
fi

# Rows: slug, branch, ahead, behind, lock, lock age, dev stack status.
if listing="$(cd "$main" && bash "$worktree_sh" list 2>&1)"; then
  merged="$(printf '%s\n' "$listing" | awk -F '\t' '$3 == "0" && ($5 == "-" || $5 ~ /\(stale\)$/) { printf " %s (%s)", $1, $2 }')"
  stale="$(printf '%s\n' "$listing" | awk -F '\t' '$5 ~ /\(stale\)$/ { printf " %s (%s, %s ago)", $1, substr($5, 1, length($5) - 8), $6 }')"
  if [ -z "$merged" ]; then
    emit worktrees.merged pass "No worktree is merged into the default branch, as of the last fetch."
  else
    emit worktrees.merged warn "Merged into the default branch, as of the last fetch:$merged"
  fi
  if [ -z "$stale" ]; then
    emit worktrees.stale-locks pass "No stale lock."
  else
    emit worktrees.stale-locks warn "Stale locks:$stale"
  fi
else
  emit worktrees.merged fail "worktree.sh list failed: $listing"
  listing=""
  emit worktrees.stale-locks skip "worktree.sh list failed."
fi

# Worktrees and locks are left out: before their gitignore entries merge they show as untracked.
dirty="$(git -C "$main" status --porcelain -- . ":(exclude)$folder" ":(exclude).sdlc")"
if [ -z "$dirty" ]; then
  emit worktrees.main-clean pass "The main checkout has no uncommitted changes."
else
  emit worktrees.main-clean warn "Uncommitted changes in the main checkout: $(printf '%s' "$dirty" | tr '\n' ';')"
fi

# Portless and the proxy

dev_script="$top/scripts/dev-stack"
project="" pinned="" cap=4 rec_port="" rec_tls=""
# The doc's field lines, in the format of skills/dev-stack/CONTRACT.md.
field() { sed -n "s/^- $1: \(.*\)\$/\1/p" "$dev_doc" | head -n 1 | tr -d '`'; }
if [ -f "$dev_doc" ]; then
  project="$(field Project)"
  pinned="$(field Portless)"
  n="$(field Cap)"
  case "$n" in ''|*[!0-9]*) ;; *) cap="$n" ;; esac
  proxy="$(field Proxy)"
  case "$proxy" in
    "HTTP on "*) rec_tls=0 rec_port="${proxy#HTTP on }" ;;
    "HTTPS on "*) rec_tls=1 rec_port="${proxy#HTTPS on }" ;;
  esac
  case "$rec_port" in *[!0-9]*) rec_port="" ;; esac
fi

# The contract's own copies of the record must match the doc.
script_drift=""
if [ -f "$dev_script" ]; then
  for pair in "PROJECT:$project" "PROXY_PORT:$rec_port" "PROXY_TLS:$rec_tls"; do
    var="${pair%%:*}" want="${pair#*:}"
    got="$(sed -n "s/^$var=\"\{0,1\}\([a-z0-9-]*\)\"\{0,1\}\$/\1/p" "$dev_script" | head -n 1)"
    [ -n "$got" ] && [ -n "$want" ] && [ "$got" != "$want" ] && script_drift="$script_drift $var=$got (doc: $want)"
  done
fi
have_portless=""
command -v portless >/dev/null 2>&1 && have_portless=1

if [ ! -f "$dev_doc" ]; then
  for id in portless.installed portless.version portless.proxy portless.doctor portless.ca portless.stale-routes; do
    emit "$id" skip "No dev stack doc: this repo runs no dev stack."
  done
elif [ -z "$have_portless" ]; then
  emit portless.installed fail "portless is not on PATH; the dev stack doc pins ${pinned:-a version}."
  for id in portless.version portless.proxy portless.doctor portless.ca portless.stale-routes; do
    emit "$id" skip "Portless is not installed."
  done
else
  emit portless.installed pass "$(command -v portless)"
  installed="$(portless --version 2>/dev/null | tr -d '[:space:]')"
  if [ -z "$pinned" ]; then
    emit portless.version warn "Installed $installed; the dev stack doc pins no version."
  elif [ "$installed" = "$pinned" ]; then
    emit portless.version pass "$installed, as pinned."
  else
    emit portless.version warn "Installed $installed; the dev stack doc pins $pinned."
  fi

  run_port="$(cat "$state_dir/proxy.port" 2>/dev/null)"
  run_tls="$(cat "$state_dir/proxy.tls" 2>/dev/null)"
  code="000"
  [ -n "$run_port" ] && code="$(curl -sk -o /dev/null -m 2 -w '%{http_code}' "http://127.0.0.1:$run_port/" 2>/dev/null)"
  [ "${code:-000}" = "000" ] && [ -n "$run_port" ] && code="$(curl -sk -o /dev/null -m 2 -w '%{http_code}' "https://127.0.0.1:$run_port/" 2>/dev/null)"
  mode() { if [ "$2" = 1 ]; then printf 'HTTPS on %s' "$1"; else printf 'HTTP on %s' "$1"; fi; }
  if [ -z "$rec_port" ]; then
    emit portless.proxy warn "The dev stack doc has no '- Proxy: HTTP on <port>' or '- Proxy: HTTPS on <port>' line."
  elif [ "${code:-000}" = "000" ]; then
    emit portless.proxy warn "No proxy running; scripts/dev-stack up starts it in the recorded mode, $(mode "$rec_port" "${rec_tls:-0}")."
  elif [ "$run_port" != "$rec_port" ] || [ "${run_tls:-0}" != "${rec_tls:-0}" ]; then
    emit portless.proxy warn "The proxy runs $(mode "$run_port" "${run_tls:-0}"); the recorded mode is $(mode "$rec_port" "${rec_tls:-0}")."
  else
    emit portless.proxy pass "Running $(mode "$run_port" "${run_tls:-0}"), as recorded."
  fi

  doctor="$(portless doctor </dev/null 2>&1)"; doctor_code=$?
  if [ "$doctor_code" -eq 0 ] && ! printf '%s\n' "$doctor" | grep -qE '^(fail|error)'; then
    emit portless.doctor pass "$(printf '%s\n' "$doctor" | grep '^Summary' | head -n 1)"
  else
    emit portless.doctor fail "$(printf '%s\n' "$doctor" | grep -E '^(fail|error|warn)' | tr '\n' ';')"
  fi
  if [ "${rec_tls:-0}" != 1 ]; then
    emit portless.ca skip "The recorded mode is HTTP."
  elif printf '%s\n' "$doctor" | grep -q '^ok.*CA is trusted'; then
    emit portless.ca pass "The Portless CA is trusted."
  else
    emit portless.ca fail "The recorded mode is HTTPS and the Portless CA is not trusted."
  fi

  if [ -z "$project" ]; then
    emit portless.stale-routes skip "The dev stack doc has no '- Project:' line."
  elif ! command -v jq >/dev/null 2>&1; then
    emit portless.stale-routes skip "jq is not on PATH."
  else
    live=" $(printf '%s\n' "$listing" | cut -f 1 | tr '\n' ' ') "
    gone=""
    # Static aliases (pid 0) outlive their server; Portless drops routes whose process died.
    while IFS= read -r host; do
      s="${host%.$project.localhost}"
      case "$s" in *.*|"$host") continue ;; esac
      case "$live" in *" $s "*) ;; *) gone="$gone ${host%.localhost}" ;; esac
    done < <(jq -r '.[] | select(.pid == 0) | .hostname' "$state_dir/routes.json" 2>/dev/null)
    if [ -z "$gone" ]; then
      emit portless.stale-routes pass "Every $project alias belongs to a worktree that exists."
    else
      emit portless.stale-routes warn "Aliases for worktrees that no longer exist:$gone"
    fi
  fi
fi

# Dev stack

stack_main=""
if [ ! -f "$dev_doc" ]; then
  for id in devstack.doc devstack.script devstack.url devstack.status; do emit "$id" skip "No dev stack doc."; done
else
  emit devstack.doc pass "docs/agents/dev-stack.md"
  if [ ! -e "$dev_script" ]; then
    emit devstack.script fail "No scripts/dev-stack."
    emit devstack.url skip "No scripts/dev-stack."
    emit devstack.status skip "No scripts/dev-stack."
  elif [ ! -x "$dev_script" ]; then
    emit devstack.script fail "scripts/dev-stack is not executable."
    emit devstack.url skip "scripts/dev-stack is not executable."
    emit devstack.status skip "scripts/dev-stack is not executable."
  elif [ -n "$script_drift" ]; then
    emit devstack.script warn "scripts/dev-stack disagrees with the dev stack doc:$script_drift"
  else
    emit devstack.script pass "scripts/dev-stack"
  fi
  if [ ! -x "$dev_script" ]; then
    :
  elif [ -z "$have_portless" ]; then
    emit devstack.url skip "Portless is not installed."
    emit devstack.status skip "Portless is not installed."
  else
    url="$(cd "$top" && scripts/dev-stack url </dev/null 2>/dev/null)"; url_code=$?
    url="$(printf "%s\n" "$url" | tail -n 1)"
    case "$url" in
      http://*|https://*) emit devstack.url pass "$url" ;;
      *) emit devstack.url fail "scripts/dev-stack url printed '$url' (exit $url_code)." ;;
    esac
    stack_main="$(cd "$top" && scripts/dev-stack status </dev/null 2>/dev/null)"; status_code=$?
    stack_main="$(printf "%s\n" "$stack_main" | tail -n 1)"
    if { [ "$status_code" -eq 0 ] && [ "$stack_main" = running ]; } || { [ "$status_code" -eq 3 ] && [ "$stack_main" = stopped ]; }; then
      emit devstack.status pass "$stack_main"
    else
      emit devstack.status fail "scripts/dev-stack status printed '$stack_main' and exited $status_code; the contract says running/0 or stopped/3."
    fi
  fi
fi

# Stack hygiene

if [ ! -f "$dev_doc" ]; then
  emit stacks.cap skip "No dev stack doc."
  emit stacks.merged skip "No dev stack doc."
else
  running="$(printf '%s\n' "$listing" | awk -F '\t' '$7 == "running"' | wc -l | tr -d ' ')"
  [ "$stack_main" = running ] && running=$((running + 1))
  if [ "$running" -gt "$cap" ]; then
    emit stacks.cap warn "$running stacks of this repo running; the cap is $cap."
  else
    emit stacks.cap pass "$running of $cap stacks of this repo running."
  fi
  merged_running="$(printf '%s\n' "$listing" | awk -F '\t' '$3 == "0" && $7 == "running" { printf " %s", $1 }')"
  if [ -z "$merged_running" ]; then
    emit stacks.merged pass "No running stack in a merged worktree."
  else
    emit stacks.merged warn "Running stacks in merged worktrees:$merged_running"
  fi
fi
