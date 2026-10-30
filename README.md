# sdlc

Agent skills for SDLC (Software Development LifeCycle): idea, spec, tickets, code, review, PR, with a glossary and ADRs kept current along the way. They work in any project repo.

The skills are plain [Agent Skills](https://agentskills.io), so they work in any coding agent that supports the standard. Claude Code gets them as a plugin, together with three hooks: a git guardrail, a comment slop check and a main-checkout guard. Codex, Cursor, Gemini CLI, Copilot, OpenCode and other agents install the same skills with `npx skills`.

## Install

Use one install path per agent. Installing both the plugin and the `npx` copy in Claude Code gives you every skill twice.

### Claude Code

For every project on your machine:

```bash
claude plugin marketplace add pumpkit-io/sdlc
claude plugin install sdlc@pumpkit-io --scope user
```

Then run `/reload-plugins` or restart. Third-party marketplaces don't auto-update by default: enable it in `/plugin`, Marketplaces tab, or run `claude plugin update sdlc@pumpkit-io`.

Prefer editable files? Use the `npx` install below instead of the plugin (`-a claude-code`); you lose the hooks.

### Codex, Cursor, Gemini CLI, Copilot, OpenCode and other agents

```bash
npx skills@latest add pumpkit-io/sdlc                 # pick agents and skills interactively
npx skills@latest add pumpkit-io/sdlc -a codex -a cursor   # or name the agents
npx skills@latest add pumpkit-io/sdlc -g              # install for your user, not this project
```

The skills land in `.agents/skills/` (the folder Codex, Cursor, Gemini CLI, Copilot and OpenCode read), as ordinary files you own and can edit. With `-g` they go to each agent's user-level folder instead. Pull later changes with `npx skills update`. If you install a subset with `--skill`, include `setup-sdlc`.

### Then, once per project repo

Run `setup-sdlc` (see [Invoking skills](#invoking-skills) for your agent's syntax). It records the repo's issue tracker and doc layout in `AGENTS.md` and `docs/agents/`, and how each new worktree gets ready to run. On GitHub it also offers a CI workflow that checks every pull request for comment slop and runs `review-changes` on it with your Claude subscription, failing the check when the review's verdict is blocking. In a repo with an app, it installs Portless, starts its proxy on plain HTTP with no `sudo`, and either drafts `scripts/dev-stack` or opens one issue listing what keeps two copies of the app from running side by side. It writes on a `chore/setup-sdlc` branch, offers a pull request, and ends by running `check-sdlc`.

Re-run `setup-sdlc` only to switch issue trackers or start over. For everything else, run `check-sdlc`: after updating the plugin, on a new machine, when something behaves oddly, or on a repo an older version set up in `CLAUDE.md`. It checks the setup on this machine and in this repo, fixes what you approve and checks again.

## Invoking skills

| Agent | Syntax | Example |
|---|---|---|
| Claude Code (plugin) | `/sdlc:<name>` | `/sdlc:to-spec` |
| Claude Code (`npx` install) | `/<name>` | `/to-spec` |
| Codex | `$<name>` | `$to-spec` |
| Cursor, Copilot | `/<name>` | `/to-spec` |
| Gemini CLI, OpenCode | ask for it by name | "use the to-spec skill" |

Automatic skills also load on their own when your request matches them. The rest of this README uses bare skill names: type them with your agent's syntax.

## Support matrix

As of 2026-10. Agents change fast; open an issue if a row is out of date.

| | Claude Code | Codex | Cursor | Copilot | Gemini CLI | OpenCode |
|---|---|---|---|---|---|---|
| Skills install and run | yes | yes | yes | yes | yes | yes |
| Command skills run only when you invoke them | yes | yes (via `agents/openai.yaml`) | yes | yes (VS Code) | no, the model may load them | no, the model may load them |
| Reference skills hidden from menus | yes | no | no | yes (VS Code) | no | no |
| Parallel sub-agents (review-changes, implement-spec, deslop, refresh-spec) | yes | not verified | not verified | not verified | not verified | not verified |
| Worktree per session, chosen by the skills | yes, and the session switches into it | yes, by absolute paths and `git -C` | yes, by absolute paths and `git -C` | yes, by absolute paths and `git -C` | yes, by absolute paths and `git -C` | yes, by absolute paths and `git -C` |
| Main checkout write guard | yes | no | no | no | no | no |
| Dev stack per worktree | yes | yes | yes | yes | yes | yes |
| Git and Portless guardrail hook (force pushes, `worktree remove --force`, proxy-breaking Portless commands) | yes | no | no | no | no | no |
| Comment slop check at commit | yes | no | no | no | no | no |
| Instruction file it reads | `CLAUDE.md`, which imports `AGENTS.md` | `AGENTS.md` | `AGENTS.md` | not verified | `GEMINI.md` (point it at `AGENTS.md`) | `AGENTS.md` |

The dev stack runs in any agent that can run shell commands, since it is only `scripts/dev-stack` and Portless. Only Claude Code moves the session into a worktree; the other agents stay where they started and work in the worktree by path, which the `worktrees` skill tells them to do.

Without sub-agents, `review-changes` runs its three reviews one after another, `deslop` runs its waves in the current session, `refresh-spec` compares one ticket at a time, and `implement-spec` stops and tells you to run `implement` one ticket at a time.

## Skill types

| Type | Triggered by | Skills |
|---|---|---|
| Command | You, by typing it | setup-sdlc, check-sdlc, update-design, deslop, grill-with-docs, to-spec, to-tickets, refresh-spec, implement, implement-spec, triage, improve-codebase-architecture, retro, handoff |
| Automatic | The agent when relevant, or you | tdd, code-comments, diagnosing-bugs, dev-stack, review-changes, pr, prose-style, ui-design, prototype, domain-modeling, setup-pre-commit, worktrees |
| Reference | Other skills only | grilling, codebase-design, writing-for-agents |

Plus three hooks in Claude Code: git guardrails, the main-checkout guard and the comment slop check (below).

## Flows

### Feature (main flow)

Open the agent in your **Main checkout**, on any branch, and type the skills below. You never create a branch or a worktree yourself: the skills do it.

```
grill-with-docs <idea>      creates .claude/worktrees/<slug>/ on feat/<slug>, then
                            interviews; updates GLOSSARY.md and ADRs there
to-spec                     spec issue on the tracker, starting "Branch: feat/<slug>"
to-tickets                  vertical-slice tickets with blocking links, each with
                            the same Branch line
(fresh session, in the main checkout again)
implement <ticket>          follows the Branch line into the feature's worktree;
                            in a repo with an app, ends with the change running
                            at its Dev URL
  or implement-spec <spec>  all tickets in parallel worktrees, unattended
review-changes main         final three-axis review of the whole branch
"open a PR"                 body shaped by the pr skill
(after merging)
worktrees sweep             removes every clean worktree whose branch is merged
```

Each skill says where it moved the session in one line (`Worktree: <path> (<branch>)`). Your routine stays the same, and your main checkout stays as you left it: no agent edits or commits there. Start as many grilling sessions at once as you like; each gets its own worktree and branch, and ADR numbers stay distinct across branches. Two sessions never share a worktree: a second `implement` on the same feature stops, names the session holding the worktree's lock, and points you to `implement-spec`.

A Dev URL looks like `http://<slug>.<project>.localhost:1355`, one per worktree, so several stacks run side by side. Open it to try what the agent built; the stack stays up until the worktree is finished.

- Tickets written a while ago: `refresh-spec <spec>` first, to update them to the code as it is now.
- Small work that fits one session: `grill-with-docs`, then `implement` in the same session and worktree.
- A raw idea with no spec: `implement <idea>` creates its own worktree on a new branch.
- Features with a UI: `ui-design` joins the grilling, its design plan goes into the spec, and implementers build to it.
- UI or state model unclear: during grilling run `handoff`, prototype in a fresh session, `handoff` back.
- Prefer `claude -w`? Start the session in a worktree yourself; the skills see they are already in one and stay.

To opt out for one session, start it with `SDLC_ALLOW_MAIN_CHECKOUT=1`: the main-checkout guard lets the agent write in your checkout. To drop the rule for a repo, delete the `### Worktrees` block from its `AGENTS.md`; the guard then does nothing there, and only the skills that resolve a worktree as their first step still create one.

### Bug

Describe the symptom. `diagnosing-bugs` creates a `fix/<slug>` worktree, builds a failing loop there first (against the worktree's dev stack when the loop needs a server), then fixes with a regression test. Then `review-changes main` and a PR. If it reports there is no good seam for the test, run `improve-codebase-architecture` on that area.

### Inbound (open-source repos, weekly)

`triage show me what needs attention`. Issues it marks `ready-for-agent` go to `implement #N`, which creates the worktree for each.

### Upkeep

- `improve-codebase-architecture` every week or two. A picked candidate becomes an idea for `grill-with-docs`. To explore several, grill each in a fresh session pointed at its section of the doc in `docs/architecture-improvements/`.
- `retro` after a session that went badly, before starting a fresh one. Mechanical mistakes become lint rules or hooks; judgement calls become lines in `CODING_STANDARDS.md`.

## Context rules

- Keep grilling, spec and tickets in one session; start a fresh session (`/clear` in Claude Code) only after `to-tickets`.
- One ticket per fresh session.
- Every unit of work lives in its own worktree under `.claude/worktrees/`, and the skills choose it before their first write. A session where no skill ran follows the same rule from `AGENTS.md`: before its first file change it resolves a `chore/` (or `feat/`, `fix/`) worktree.
- New worktrees branch from `origin/<default>`, not from what your main checkout has checked out. A skill that needs the branch your main checkout is on stops and tells you, rather than switch your checkout.

## Files the skills expect in each project repo

| File | Written by | Read by |
|---|---|---|
| `AGENTS.md` | you, setup | every session (directly, or through `CLAUDE.md` / `GEMINI.md`): keep it to pointers |
| `CLAUDE.md` containing `@AGENTS.md` | you, setup | Claude Code |
| `GLOSSARY.md`, `docs/adr/` | grill-with-docs, domain-modeling, improve-codebase-architecture | everything |
| `docs/architecture-improvements/` (gitignored) | improve-codebase-architecture | a fresh session grilling one candidate |
| `docs/agents/*.md` | setup | to-spec, to-tickets, implement-spec, triage, review-changes |
| `CODING_STANDARDS.md` | you, retro | review-changes only |
| `.out-of-scope/` | triage | triage |
| `DESIGN.md` (repos with a UI) | setup, update-design | ui-design, deslop, review-changes |
| `.github/workflows/sdlc-review.yml` (GitHub repos) | setup | GitHub Actions, on every pull request |
| `docs/agents/worktrees.md` | setup | worktrees: the files copied into each new worktree and its install command |
| `docs/agents/dev-stack.md` (repos with an app) | setup | dev-stack, implement, implement-spec, check-sdlc: the strategy, project name, Portless version and proxy mode, and the stack cap |
| `scripts/dev-stack` (repos with an app) | setup, or `implement` on the "Make the dev stack worktree-safe" issue | dev-stack, worktrees, check-sdlc: the contract's `up`, `down`, `destroy`, `url`, `status` and `logs` |
| `.claude/worktrees/` (gitignored) | worktrees | every writing skill: one worktree per unit of work |
| `.sdlc/` (gitignored, in each worktree) | worktrees, dev-stack | worktrees: the session lock; the dev stack's pids, logs and screenshots under `.sdlc/dev-stack/` |

Gemini CLI reads `GEMINI.md`: import `AGENTS.md` from it, or set `context.fileName` to include `AGENTS.md`.

## Git guardrails

The guardrail runs in Claude Code only, as an always-on `PreToolUse` hook shipped with the plugin (`hooks/block-dangerous-git.sh`, needs `jq` and `perl`). It blocks force, mirror and delete pushes, `reset --hard`, `clean -f`, `branch -D`, `checkout .` / `restore .`, `worktree remove -f` / `--force`, skipping git hooks (`--no-verify`, `-c core.hooksPath`), `gh pr merge`, `gh repo delete`, visibility changes, and `gh api` calls that merge a PR, change rulesets or branch protection, or delete a repository.

It also blocks the Portless commands that break the shared proxy or another worktree's route: `portless proxy stop`, `portless clean`, `portless hosts clean`, `portless service uninstall` and `portless run --force`, also when run through `npx`, `pnpm dlx` or another package launcher. It allows `portless prune` and `portless alias … --force`, which a dev stack contract uses on its own route ([ADR 0005](./docs/adr/0005-dev-stacks-only-through-the-repo-contract.md)). Pushes are otherwise allowed, to any branch: whether `main` takes direct pushes is up to each repo's branch protection. Merging stays with the human. Change `PUSH_POLICY` in the script to `none` to block all pushes.

The hook checks the arguments of each `git`, `gh` and `portless` command in the line, so a commit message, PR body or heredoc that mentions `reset --hard` doesn't trip it, and neither does `gh pr create --base main` chained after a push. It also checks commands run through `sh -c`, `eval` and a heredoc fed to a shell.

In other agents, rely on the agent's own approval or sandbox mode for the same protection. [ADR 0002](./docs/adr/0002-agent-neutral-skills-single-native-package.md) explains why the hook isn't ported yet.

## Main-checkout guard

A third `PreToolUse` hook (`hooks/guard-main-checkout.sh`, needs `jq` and `perl`) keeps agents out of your **Main checkout** in Claude Code ([ADR 0004](./docs/adr/0004-one-worktree-per-unit-of-work-chosen-by-the-skills.md)). It acts only in a repo whose `AGENTS.md` (or, for older setups, `CLAUDE.md`) has the `### Worktrees` rule, and finds the main checkout through git's common dir, so it works the same from any worktree.

It blocks `Edit`, `Write`, `MultiEdit` and `NotebookEdit` on files in the main checkout. It allows edits in the worktrees folder (`.claude/worktrees/`, or the Folder set in `docs/agents/worktrees.md`), in `.sdlc/`, in `docs/architecture-improvements/`, and anywhere outside the repo, such as memory and temp files. In Bash it blocks `git commit`, `add`, `rm`, `mv`, `restore`, `reset`, `clean` (except a dry run), `checkout`, `switch`, `merge` and `pull` (except with `--ff-only`), `rebase`, `stash` (except `list` and `show`), `cherry-pick`, `revert`, `apply` and `am` when they run in the main checkout, including through `cd` or `git -C`; the same commands in a worktree pass. The block message tells the agent to load the `worktrees` skill, resolve a worktree and retry there.

Start a session with `SDLC_ALLOW_MAIN_CHECKOUT=1` set to let an agent write in your checkout on purpose. Shell redirections into the checkout are not caught; the `AGENTS.md` rule covers them. In other agents the rule and the `worktrees` skill are the only layers.

## Comment slop check

A second `PreToolUse` hook (`hooks/check-commit-slop.sh`, needs `jq` and `perl`) runs before every `git commit` in Claude Code. It checks the comment lines the commit adds for the slop the `code-comments` skill bans that a pattern can catch: em-dashes, banner headers, `Step 1:` narration, emoji, `// end if` markers, empty labels, TODOs that name no task, and doc lines that only repeat a parameter's name. On a finding it blocks the commit and lists the lines, so the agent fixes them and commits again. Judgement calls, like a comment that restates its line, stay with `review-changes`. A false positive can be committed with `SDLC_ALLOW_SLOP=1 git commit ...`, and the agent has to say why.

The check itself is `hooks/comment-slop.pl`, which reads any unified diff. The CI workflow `setup-sdlc` installs runs it on every pull request, so commits from other agents and from people are checked too.

## Credits and upstream

Forked from [mattpocock/skills](https://github.com/mattpocock/skills) at `d81f3a183412e71a5b1e84ca21bc1a35eea03a60` (2026-10-03), then trimmed to the skills above, flattened and renamed. The `pr` skill's summary visuals come from Dex Horthy's `show-me` skill (see [skills/pr/CREDITS.md](./skills/pr/CREDITS.md)).

This repo no longer merges from upstream. To port an upstream improvement to a skill kept here:

```bash
git fetch upstream
git diff d81f3a1 upstream/main -- skills/<bucket>/<name>/   # upstream still uses bucket folders
```

Apply what's worth keeping to `skills/<name>/` by hand, then re-check the skill for references to skills that don't exist here.

`ui-design` is Anthropic's `frontend-design` skill (Apache 2.0) from [anthropics/skills](https://github.com/anthropics/skills) at `ca45fc496a3436251f191354091d557da31c15b5`, copied word for word with a section added for `DESIGN.md`, the spec flow and review. Its [CREDITS.md](./skills/ui-design/CREDITS.md) says how to port a later change.

The slop rules are ported and adapted from [miqdadbadjuber/anti-slop](https://github.com/miqdadbadjuber/anti-slop) (MIT) at `91f12ec67e9de6043cfd93b846404986ba73c3f4`, and each ported skill carries its own `CREDITS.md`. This repo never merges from anti-slop either: to port a later change, diff anti-slop from that commit and apply what's worth keeping by hand.

## License

MIT. See [LICENSE](./LICENSE).
