# sdlc

Agent skills for SDLC (Software Development LifeCycle): idea, spec, tickets, code, review, PR, with a glossary and ADRs kept current along the way. It is the agent harness used across pumpkit-io projects.

The skills are plain [Agent Skills](https://agentskills.io), so they work in any coding agent that supports the standard. Claude Code gets them as a plugin, together with a git guardrail hook. Codex, Cursor, Gemini CLI, Copilot, OpenCode and other agents install the same skills with `npx skills`.

## Install

Use one install path per agent. Installing both the plugin and the `npx` copy in Claude Code gives you every skill twice.

### Claude Code

For every project on your machine:

```bash
claude plugin marketplace add pumpkit-io/sdlc
claude plugin install sdlc@pumpkit-io --scope user
```

Then run `/reload-plugins` or restart. Third-party marketplaces don't auto-update by default: enable it in `/plugin`, Marketplaces tab, or run `claude plugin update sdlc@pumpkit-io`.

Prefer editable files? Use the `npx` install below instead of the plugin (`-a claude-code`); you lose the git guardrail hook.

### Codex, Cursor, Gemini CLI, Copilot, OpenCode and other agents

```bash
npx skills@latest add pumpkit-io/sdlc                 # pick agents and skills interactively
npx skills@latest add pumpkit-io/sdlc -a codex -a cursor   # or name the agents
npx skills@latest add pumpkit-io/sdlc -g              # install for your user, not this project
```

The skills land in `.agents/skills/` (the folder Codex, Cursor, Gemini CLI, Copilot and OpenCode read), as ordinary files you own and can edit. With `-g` they go to each agent's user-level folder instead. Pull later changes with `npx skills update`. If you install a subset with `--skill`, include `setup-sdlc`.

### Then, once per project repo

Run `setup-sdlc` (see [Invoking skills](#invoking-skills) for your agent's syntax). It records the repo's issue tracker and doc layout in `AGENTS.md` and `docs/agents/`.

Already set up a repo with an older version that wrote to `CLAUDE.md`? Re-run `setup-sdlc` once: it moves the block to `AGENTS.md`, where other agents can see it.

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
| Parallel sub-agents (code-review, implement-spec) | yes | not verified | not verified | not verified | not verified | not verified |
| Git guardrail hook | yes | no | no | no | no | no |
| Instruction file it reads | `CLAUDE.md`, which imports `AGENTS.md` | `AGENTS.md` | `AGENTS.md` | not verified | `GEMINI.md` (point it at `AGENTS.md`) | `AGENTS.md` |

Without sub-agents, `code-review` runs its two reviews one after another, and `implement-spec` stops and tells you to run `implement` one ticket at a time.

## Skill types

| Type | Triggered by | Skills |
|---|---|---|
| Command | You, by typing it | setup-sdlc, grill-with-docs, to-spec, to-tickets, implement, implement-spec, triage, improve-codebase-architecture, retro, handoff |
| Automatic | The agent when relevant, or you | tdd, diagnosing-bugs, code-review, pr, prose-style, prototype, domain-modeling, setup-pre-commit |
| Reference | Other skills only | grilling, codebase-design, writing-for-agents |

Plus one hook in Claude Code: git guardrails (below).

## Flows

### Feature (main flow)

```
git checkout -b feat/<name>
grill-with-docs <idea>      interview; updates GLOSSARY.md and ADRs
to-spec                     spec issue on the tracker
to-tickets                  vertical-slice tickets with blocking links
(fresh session)
implement <ticket>          one ticket per fresh session
  or implement-spec <spec>  all tickets in parallel worktrees, unattended
code-review main            final two-axis review of the whole branch
"open a PR"                 body shaped by the pr skill
```

- Small work that fits one session: `grill-with-docs`, then `implement` in the same session.
- UI or state model unclear: during grilling run `handoff`, prototype in a fresh session, `handoff` back.

### Bug

Describe the symptom. `diagnosing-bugs` builds a failing loop first, then fixes with a regression test. Then `code-review main` and a PR. If it reports there is no good seam for the test, run `improve-codebase-architecture` on that area.

### Inbound (open-source repos, weekly)

`triage show me what needs attention`. Issues it marks `ready-for-agent` go to `implement #N` on a branch.

### Upkeep

- `improve-codebase-architecture` every week or two. A picked candidate becomes an idea for `grill-with-docs`. To explore several, grill each in a fresh session pointed at its section of the doc in `docs/architecture-improvements/`.
- `retro` after a session that went badly, before starting a fresh one. Mechanical mistakes become lint rules or hooks; judgement calls become lines in `CODING_STANDARDS.md`.

## Context rules

- Keep grilling, spec and tickets in one session; start a fresh session (`/clear` in Claude Code) only after `to-tickets`.
- One ticket per fresh session.
- `implement` commits to the current branch: create the branch first.

## Files the skills expect in each project repo

| File | Written by | Read by |
|---|---|---|
| `AGENTS.md` | you, setup | every session (directly, or through `CLAUDE.md` / `GEMINI.md`): keep it to pointers |
| `CLAUDE.md` containing `@AGENTS.md` | you, setup | Claude Code |
| `GLOSSARY.md`, `docs/adr/` | grill-with-docs, domain-modeling, improve-codebase-architecture | everything |
| `docs/architecture-improvements/` (gitignored) | improve-codebase-architecture | a fresh session grilling one candidate |
| `docs/agents/*.md` | setup | to-spec, to-tickets, implement-spec, triage, code-review |
| `CODING_STANDARDS.md` | you, retro | code-review only |
| `.out-of-scope/` | triage | triage |

Gemini CLI reads `GEMINI.md`: import `AGENTS.md` from it, or set `context.fileName` to include `AGENTS.md`.

## Git guardrails

The guardrail runs in Claude Code only, as an always-on `PreToolUse` hook shipped with the plugin (`hooks/block-dangerous-git.sh`, needs `jq`). It blocks: force pushes, pushes to main/master, remote branch deletion, `reset --hard`, `clean -f`, `branch -D`, `checkout .` / `restore .`, `gh pr merge`, `gh repo delete` and visibility changes. Pushing feature branches and opening PRs stays allowed, so unattended runs can publish their work while merging stays with the human. Change `PUSH_POLICY` in the script to `none` to block all pushes.

In other agents, rely on the agent's own approval or sandbox mode for the same protection. [ADR 0002](./docs/adr/0002-agent-neutral-skills-single-native-package.md) explains why the hook isn't ported yet.

## Credits and upstream

Forked from [mattpocock/skills](https://github.com/mattpocock/skills) at `d81f3a183412e71a5b1e84ca21bc1a35eea03a60` (2026-10-03), then trimmed to the skills above, flattened and renamed. The `pr` skill's summary visuals come from Dex Horthy's `show-me` skill (see [skills/pr/CREDITS.md](./skills/pr/CREDITS.md)).

The slop-filtering skills are ported and adapted from [miqdadbadjuber/anti-slop](https://github.com/miqdadbadjuber/anti-slop) (MIT) at `91f12ec67e9de6043cfd93b846404986ba73c3f4`; each ported skill carries its own `CREDITS.md`. This repo never merges from it: to port a later change, diff upstream from that commit and apply it by hand.

This repo no longer merges from upstream. To port an upstream improvement to a skill kept here:

```bash
git fetch upstream
git diff d81f3a1 upstream/main -- skills/<bucket>/<name>/   # upstream still uses bucket folders
```

Apply what's worth keeping to `skills/<name>/` by hand, then re-check the skill for references to skills that don't exist here.

## License

MIT. See [LICENSE](./LICENSE).
