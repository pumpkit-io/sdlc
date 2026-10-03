# sdlc

A curated, lightly adapted fork of [mattpocock/skills](https://github.com/mattpocock/skills) (MIT), packaged as one Claude Code plugin. It is the agent harness used across pumpkit-io projects: idea, spec, tickets, code, review, PR, with a glossary and ADRs kept current along the way.

What differs from upstream, and how to sync: [FORK.md](./FORK.md).

## Install

Claude Code, for every project on your machine:

```bash
claude plugin marketplace add pumpkit-io/sdlc
claude plugin install sdlc@pumpkit-io --scope user
```

Then run `/reload-plugins` or restart. Skills appear as `/sdlc:<name>`. Third-party marketplaces don't auto-update by default: enable it in `/plugin`, Marketplaces tab, or run `claude plugin update sdlc@pumpkit-io`.

Codex and other agents (copies editable skill files into a project; pick the ones listed below):

```bash
npx skills@latest add pumpkit-io/sdlc
```

Then, once in every project repo: `/sdlc:setup-matt-pocock-skills`.

## Skill types

| Type | Triggered by | Skills |
|---|---|---|
| Command | You, by typing it | setup-matt-pocock-skills, grill-with-docs, to-spec, to-tickets, implement, implement-spec, triage, improve-codebase-architecture, retro, handoff |
| Automatic | The agent when relevant, or you | tdd, diagnosing-bugs, code-review, pr, prototype, domain-modeling, setup-pre-commit |
| Reference | Other skills only | grilling, codebase-design, writing-for-agents |

Plus one always-on hook: git guardrails (below).

## Flows

### Feature (main flow)

```
git checkout -b feat/<name>
/sdlc:grill-with-docs <idea>      interview; updates GLOSSARY.md and ADRs
/sdlc:to-spec                     spec issue on the tracker
/sdlc:to-tickets                  vertical-slice tickets with blocking links
/clear
/sdlc:implement <ticket>          one ticket per fresh session, /clear between
  or /sdlc:implement-spec <spec>  all tickets in parallel worktrees, unattended
/sdlc:code-review main            final two-axis review of the whole branch
"open a PR"                       body shaped by the pr skill
```

- Small work that fits one session: `/sdlc:grill-with-docs`, then `/sdlc:implement` in the same session.
- UI or state model unclear: during grilling run `/sdlc:handoff`, prototype in a fresh session, `/sdlc:handoff` back.

### Bug

Describe the symptom. `diagnosing-bugs` builds a failing loop first, then fixes with a regression test. Then `/sdlc:code-review main` and a PR. If it reports there is no good seam for the test, run `/sdlc:improve-codebase-architecture` on that area.

### Inbound (open-source repos, weekly)

`/sdlc:triage show me what needs attention`. Issues it marks `ready-for-agent` go to `/sdlc:implement #N` on a branch.

### Upkeep

- `/sdlc:improve-codebase-architecture` every week or two. A picked candidate becomes an idea for `grill-with-docs`.
- `/sdlc:retro` after a session that went badly, before `/clear`. Mechanical mistakes become lint rules or hooks; judgement calls become lines in `CODING_STANDARDS.md`.

## Context rules

- Keep grilling, spec and tickets in one session; clear only after `to-tickets`.
- One ticket per fresh session.
- `implement` commits to the current branch: create the branch first.

## Files the skills expect in each project repo

| File | Written by | Read by |
|---|---|---|
| `AGENTS.md` (+ `CLAUDE.md` containing `@AGENTS.md`) | you, setup | every session: keep it to pointers |
| `GLOSSARY.md`, `docs/adr/` | grill-with-docs, domain-modeling, improve-codebase-architecture | everything |
| `docs/agents/*.md` | setup | to-spec, to-tickets, implement-spec, triage, code-review |
| `CODING_STANDARDS.md` | you, retro | code-review only |
| `.out-of-scope/` | triage | triage |

## Git guardrails

An always-on `PreToolUse` hook (`hooks/block-dangerous-git.sh`, needs `jq`) blocks: force pushes, pushes to main/master, remote branch deletion, `reset --hard`, `clean -f`, `branch -D`, `checkout .` / `restore .`, `gh pr merge`, `gh repo delete` and visibility changes. Pushing feature branches and opening PRs stays allowed, so unattended runs can publish their work while merging stays with the human. Change `PUSH_POLICY` in the script to `none` to block all pushes.

## License

MIT, as upstream. See [LICENSE](./LICENSE).
