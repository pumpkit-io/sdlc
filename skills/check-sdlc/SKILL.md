---
name: check-sdlc
description: "Check that this machine and repo are set up for the sdlc skills, apply the fixes you approve, and check again until everything passes."
disable-model-invocation: true
---

# Check sdlc

Verify every requirement of the harness on this machine and in this repo, show one table, ask once which fixes to apply, apply them, and check again. [CHECKS.md](CHECKS.md) is the checklist: each check's id, how it runs, when it passes, its fix, the fix's kind and the `setup-sdlc` section that owns it. `scripts/check.sh` in this skill's folder runs the mechanical half and changes nothing.

## 1. Check

1. Run `bash <this skill's folder>/scripts/check.sh` from anywhere in the repo. It prints one JSON line per check: `id`, `status` (`pass`, `warn`, `fail` or `skip`) and `detail`.
2. If `setup.present` fails, the repo was never set up. Say one line, "This repo has no sdlc setup yet: run `setup-sdlc`.", and stop.
3. Run the **judgment** rows of CHECKS.md yourself and give each a status and a detail the same way. Skip `agent.hooks` outside Claude Code, and keep `devstack.smoke` aside for the question.

Done when every row of CHECKS.md has a status.

## 2. Report

When every check passes or skips, print one line and stop: `check-sdlc: all <n> checks pass (<k> skipped).`

Otherwise show one table of the checks that warn or fail, in CHECKS.md's order, with the check, its status, its detail and the proposed fix. For `ci.template`, show the diff under the table.

## 3. Ask once

Ask one question listing every fix for the table's checks, grouped by kind as CHECKS.md defines them:

- **automatic** and **approval** fixes, each preselected, with the exact file change or command it makes.
- **user-only** fixes, listed with their exact command for the user to run. They are not offered for you to run.
- **setup choice** items, each pointing to its `setup-sdlc` section instead of a fix.
- `devstack.smoke`, unselected, when every other dev stack check passes.

If your agent has a multi-select question tool, use it. Otherwise number the selectable fixes and ask which to drop: "Reply `go` to apply all, or list the numbers to skip."

Done when the user has answered or said stop.

## 4. Fix

Apply only the selected fixes.

- **Machine fixes** (installs, `git worktree prune`, `worktree.sh` sweeps and releases, `portless alias --remove` on the listed routes, the proxy start in HTTP mode) run directly, from the main checkout.
- **Repo-file fixes** land on one worktree. Load the `worktrees` skill and resolve the worktree for this work before writing anything. Its branch is `chore/sdlc-fixes`. Make one commit per fix there, with a message naming the check (`chore(sdlc): add the .sdlc/ gitignore entry`). Every round reuses the same worktree.
- **Issues** (`devstack.url`, `devstack.status`, `devstack.blockers`) go to the issue tracker through `docs/agents/issue-tracker.md`, one issue for all of them.

When a fix fails, keep going with the others and report it in the next table.

## 5. Check again

Run the script again, passing the `chore/sdlc-fixes` worktree as its argument once it exists (`check.sh <path>`), so repo-file checks read the fixed files while machine checks still read this machine and the main checkout. Re-run the judgment checks that did not pass. Then go back to step 2, offering only what still fails.

The loop ends when everything passes, or when the user stops or declines every remaining fix.

## 6. Hand over the fixes

When `chore/sdlc-fixes` holds commits, offer a pull request (load the `pr` skill for its body). Fast-forward the default branch instead only when the user says yes to that explicitly: with the main checkout on `<default>` and clean, run `git -C <main> merge --ff-only chore/sdlc-fixes`, then offer to push `<default>`. That fast-forward is the one write to the main checkout this skill makes.

Release this session's worktree lock, as the `worktrees` skill's Release section says. After a fast-forward, finish the worktree with `worktree.sh finish <path> --merged-into <default>`.

## Boundaries

- Never change a setup choice: the issue tracker, the triage labels, the domain layout, the design direction, whether CI review is installed, the proxy mode or the dev stack strategy. Point to the section that owns it.
- Leave the Portless proxy as it is, apart from starting it in HTTP mode when it is down. Stopping, restarting or reconfiguring it, and every command the git and Portless guardrail blocks, are the user's to run.
- Remove only the routes `portless.stale-routes` lists. A route of a worktree that exists stays, even when its stack is stopped.
- Read the CI secret by name only. Never ask for the token or handle it.
- The main checkout's uncommitted changes are the user's: report them, never move or discard them.
