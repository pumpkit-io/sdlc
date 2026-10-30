# The check-sdlc checklist

One row per check. `scripts/check.sh` runs every check whose How is **script** and prints it as a JSON line with the row's id; the agent runs the rows marked **judgment**. `setup-sdlc` runs this same checklist as its last step.

Each row gives the fix and its kind:

- **automatic**: a mechanical fix with one right answer. Preselected.
- **approval**: a fix the user should see before it runs, such as replacing a file they may have edited or removing a route. Preselected; show what it changes in the question.
- **user-only**: needs `sudo`, a secret, the user's own checkout, or a command the guardrail blocks for agents. Never run it: list the exact command for the user.
- **setup choice**: the fix would change a decision `setup-sdlc` asked the user to make. Never offered: point to the named section.

`<main>` is the **Main checkout**, `<default>` the default branch, `<pinned>` the version on the `- Portless:` line of `docs/agents/dev-stack.md` (format in `skills/dev-stack/CONTRACT.md`), `<wt>` the path of `skills/worktrees/scripts/worktree.sh`. Setup sections are those of `setup-sdlc`: A Issue tracker, B Triage labels, C Domain docs, D Design direction, E CI review, F Worktrees, G Portless, H Dev stack, and step 4, Write, for the `## Agent skills` block.

## Setup

| id | What | How | Pass when | Fix | Kind | Section |
|---|---|---|---|---|---|---|
| `setup.present` | The repo was ever set up | script | `AGENTS.md` or `CLAUDE.md` has `## Agent skills`, or `docs/agents/` holds the tracker or domain doc | Run `setup-sdlc`. When this fails the script prints nothing else. | setup choice | all |

## Agent and plugin

| id | What | How | Pass when | Fix | Kind | Section |
|---|---|---|---|---|---|---|
| `agent.jq` | `jq` for the hooks | script | `jq` is on `PATH` | `brew install jq` on macOS; `sudo apt-get install jq` on Debian and Ubuntu | approval (user-only when it needs `sudo`) | none |
| `agent.perl` | `perl` for the hooks | script | `perl` is on `PATH` | `brew install perl`; `sudo apt-get install perl` | approval (user-only when it needs `sudo`) | none |
| `agent.skills-once` | Each sdlc skill is installed once | judgment | Your list of available skills names each sdlc skill once; in Claude Code, not both as `sdlc:<name>` and `<name>` | Remove one install, as the README's Install section says: `claude plugin uninstall sdlc@pumpkit-io`, or delete the `npx` copy from `.claude/skills/` or `.agents/skills/` | user-only | none |
| `agent.hooks` | The guardrail, guard and slop hooks run | judgment | Claude Code only: `claude plugin list` shows `sdlc` enabled. Skip in other agents, which have no hooks. | `claude plugin enable sdlc@pumpkit-io`, then `/reload-plugins` | user-only | none |

## Repo instructions

| id | What | How | Pass when | Fix | Kind | Section |
|---|---|---|---|---|---|---|
| `instructions.agents-block` | The block sits where every agent reads it | script | `AGENTS.md` has `## Agent skills`. Warns when only `CLAUDE.md` has it. | Move the block from `CLAUDE.md` to `AGENTS.md` and add `@AGENTS.md` to `CLAUDE.md`, as setup's step 4 describes | approval | step 4 |
| `instructions.claude-import` | Claude Code reads `AGENTS.md` | script | `CLAUDE.md` is a symlink to `AGENTS.md` or has an `@AGENTS.md` line. Warns when there is no `CLAUDE.md`. | Add `@AGENTS.md` as the first line of `CLAUDE.md`; with no `CLAUDE.md`, create one holding that line | automatic (approval to create the file) | step 4 |
| `instructions.old-claude-block` | No second copy of the block | script | `CLAUDE.md` holds no `## Agent skills` block once `AGENTS.md` has one | Delete the block from `CLAUDE.md` | approval | step 4 |
| `instructions.code-comments` | The code-comments pointer | script | The block has `### Code comments` | Add the sub-block as setup's step 4 writes it | automatic | step 4 |
| `instructions.worktrees-rule` | The worktrees rule | script | The block has `### Worktrees` | Add the sub-block as setup's step 4 writes it | automatic | step 4 |
| `instructions.dev-stack-pointer` | The dev stack pointer | script | With `docs/agents/dev-stack.md`, the block has `### Dev stack`. Skips without the doc. | Add the sub-block as setup's Section H writes it | automatic | H |

## Issue tracker

| id | What | How | Pass when | Fix | Kind | Section |
|---|---|---|---|---|---|---|
| `tracker.doc` | The tracker doc and its pointer | script | `docs/agents/issue-tracker.md` exists and the block has `### Issue tracker` | Doc missing: setup choice. Pointer missing: add the sub-block with a one-line summary of the doc. | setup choice; automatic for the pointer | A |
| `tracker.cli` | The tracker's CLI works | script | The doc names `gh` or `glab` and that CLI is on `PATH` and signed in. Skips for other trackers. | `brew install gh` or `brew install glab`, then `gh auth login` or `glab auth login` | user-only | A |
| `tracker.triage-labels` | Label overrides and their pointer agree | script | Both `### Triage labels` and `docs/agents/triage-labels.md` exist, or neither does | File missing: setup choice. Pointer missing: add the sub-block. | setup choice; automatic for the pointer | B |

## Domain docs

| id | What | How | Pass when | Fix | Kind | Section |
|---|---|---|---|---|---|---|
| `domain.doc` | The domain doc and its pointer | script | `docs/agents/domain.md` exists and the block has `### Domain docs` | Restore the doc from setup's `domain.md` template with the layout the block names, and add the pointer if missing. When the block names no layout, the layout is a setup choice. | automatic | C |

## Design

| id | What | How | Pass when | Fix | Kind | Section |
|---|---|---|---|---|---|---|
| `design.doc` | `DESIGN.md` holds a direction | script | `DESIGN.md` differs from setup's empty skeleton. Skips without `DESIGN.md`. | Fill it with `update-design` | setup choice | D |
| `design.needed` | A repo with a UI has a direction | judgment | The repo has no UI by setup's Explore signals, or it has a `DESIGN.md` | Run Section D of `setup-sdlc` | setup choice | D |

## CI review

All three skip when `origin` is not on GitHub.

| id | What | How | Pass when | Fix | Kind | Section |
|---|---|---|---|---|---|---|
| `ci.workflow` | The review workflow is installed | script | `.github/workflows/sdlc-review.yml` exists | Run Section E of `setup-sdlc` | setup choice | E |
| `ci.template` | The workflow matches the shipped template | script | The file is byte-identical to setup's `sdlc-review.yml` | Show the diff the detail names, then replace the file with the template | approval | E |
| `ci.secret` | The review job has its token | script | `gh secret list` names `CLAUDE_CODE_OAUTH_TOKEN`. Only the name is read; skips when `gh` can't list secrets. | `claude setup-token`, then `gh secret set CLAUDE_CODE_OAUTH_TOKEN` | user-only | E |

## Worktrees

| id | What | How | Pass when | Fix | Kind | Section |
|---|---|---|---|---|---|---|
| `worktrees.gitignore` | Worktrees and locks stay out of git | script | `git check-ignore` covers the worktrees folder and `.sdlc/` | Append the missing entries to `.gitignore` | automatic | F |
| `worktrees.doc` | New worktrees get bootstrapped | script | `docs/agents/worktrees.md` exists | Run Section F of `setup-sdlc` | setup choice | F |
| `worktrees.bootstrap` | The files to copy exist | script | Every path under the doc's Copy exists in the main checkout | Remove the stale bullet from Copy; or the user creates the file in the main checkout | approval | F |
| `worktrees.missing-dirs` | No worktree registered without its folder | script | `git worktree list --porcelain` shows nothing `prunable` | `git -C <main> worktree prune` | automatic | none |
| `worktrees.merged` | No leftover merged worktrees | script | No unlocked worktree has zero commits ahead of `origin/<default>`, as of the last fetch | `bash <wt> sweep`, which fetches first and leaves anything dirty, locked or unmerged | approval | none |
| `worktrees.stale-locks` | No abandoned locks | script | No lock is stale (two hours with no file change and no commit) | `bash <wt> release <path>` for each lock the user confirms no session holds | approval | none |
| `worktrees.main-clean` | The main checkout holds no agent changes | script | `git -C <main> status --porcelain` is empty outside the worktrees folder and `.sdlc/` | Review with `git -C <main> status`, then commit, move or discard the changes yourself | user-only | none |

## Portless and the proxy

All skip when the repo has no `docs/agents/dev-stack.md`, and all but `portless.installed` skip when Portless is not installed. The script never runs a Portless command that writes: only `--version` and `doctor`, and it reads the routes from `routes.json` in `$PORTLESS_STATE_DIR` (default `~/.portless`).

| id | What | How | Pass when | Fix | Kind | Section |
|---|---|---|---|---|---|---|
| `portless.installed` | Portless is on this machine | script | `portless` is on `PATH` | `npm install -g portless@<pinned>` into the user-owned npm prefix | approval (user-only when the prefix needs `sudo`) | G |
| `portless.version` | The pinned version | script | `portless --version` equals `<pinned>`. Warns on a mismatch. | `npm install -g portless@<pinned>` | approval | G |
| `portless.proxy` | The proxy runs in the recorded mode | script | A proxy answers on the port in `$PORTLESS_STATE_DIR/proxy.port` in the mode on the doc's `- Proxy:` line | Not running, HTTP mode: `PORTLESS_SYNC_HOSTS=0 portless proxy start -p <port> --no-tls` (automatic). Not running, HTTPS mode: the upgrade command in the doc (user-only). Another mode: `portless proxy stop`, then the recorded start command, or keep it and change the recorded mode in Section G (user-only). | see Fix | G |
| `portless.doctor` | Portless's own health check | script | `portless doctor` exits 0 with no `fail` line | Run the command the failing line suggests | user-only | G |
| `portless.ca` | Browsers and tools trust HTTPS Dev URLs | script | In HTTPS mode, `portless doctor` reports the CA trusted. Skips in HTTP mode. | `portless trust` | user-only | G |
| `portless.stale-routes` | No aliases left by deleted worktrees | script | Every static alias `<slug>.<project>.localhost` has a live worktree with that Slug; the main checkout's `<project>.localhost` is never stale | `portless alias --remove <slug>.<project>` for each route the detail lists, and no other | approval | none |
| `portless.smoke` | A route answers end to end | judgment | Run from the main checkout: start `portless run --name sdlc-smoke node -e 'require("http").createServer((q, s) => s.end("ok")).listen(process.env.PORT)'` in the background, `curl` the URL `portless get sdlc-smoke` prints (with `--cacert ~/.portless/ca.pem` for `https://`) and get `ok`, then stop that process, which removes its route | Read `portless doctor` and the proxy log in `~/.portless/proxy.log`; the fix is usually `portless.proxy`'s | user-only | G |

## Dev stack

The script's dev stack checks skip without `docs/agents/dev-stack.md`.

| id | What | How | Pass when | Fix | Kind | Section |
|---|---|---|---|---|---|---|
| `devstack.needed` | A repo with an app has a contract | judgment | The repo has no runnable app by setup's Explore signals, or it has the dev stack doc | Run Section H of `setup-sdlc` | setup choice | H |
| `devstack.doc` | The dev stack doc | script | `docs/agents/dev-stack.md` exists | Run Section H | setup choice | H |
| `devstack.script` | The contract's entry point | script | `scripts/dev-stack` exists and is executable, and its `PROJECT`, `PROXY_PORT` and `PROXY_TLS` match the doc's Project and Proxy lines. Warns on a mismatch. | Missing: Section H, or the open "Make the dev stack worktree-safe" issue (setup choice). Not executable: `chmod +x scripts/dev-stack` and `git update-index --chmod=+x scripts/dev-stack` (automatic). Mismatch: set the script's variables to the doc's values (approval). | see Fix | H |
| `devstack.url` | `url` answers | script | `scripts/dev-stack url` prints an `http://` or `https://` URL as its last line. Skips without Portless. | File one issue on the tracker, "Make scripts/dev-stack follow the dev stack contract", with the detail | approval | H |
| `devstack.status` | `status` answers | script | `scripts/dev-stack status` prints `running` with exit 0 or `stopped` with exit 3. Skips without Portless. | The same issue as `devstack.url` | approval | H |
| `devstack.blockers` | No new isolation blockers | judgment | Setup's Explore finds none of the blockers it lists (fixed host ports, a fixed Compose name, hard-coded app URLs, e2e URLs pinned to a port, a shared database, workers with outside effects) that the contract doesn't already handle | File one issue, "Make the dev stack worktree-safe", listing each blocker with its file | approval | H |
| `devstack.smoke` | The contract works in a fresh worktree | judgment, optional | Offered unselected, only when every other dev stack check passes: `bash <wt> create chore/sdlc-smoke`, then in it `scripts/dev-stack up` prints a Dev URL, `status` prints `running`, the health URL answers, and `scripts/dev-stack destroy` exits 0; then `bash <wt> finish <path>` | Read `scripts/dev-stack logs` in the smoke worktree and file the `devstack.url` issue with what it shows | approval | H |

## Stack hygiene

Both skip without `docs/agents/dev-stack.md`.

| id | What | How | Pass when | Fix | Kind | Section |
|---|---|---|---|---|---|---|
| `stacks.cap` | Running stacks stay under the cap | script | This repo's running stacks (from `bash <wt> list` and the main checkout's `status`) are at most the doc's cap | `(cd <worktree> && scripts/dev-stack down)` for the stacks the user picks | user-only | none |
| `stacks.merged` | No stack left in a merged worktree | script | No worktree with zero commits ahead of `origin/<default>` has a running stack | `bash <wt> finish <path>`, which destroys the stack first | approval | none |
