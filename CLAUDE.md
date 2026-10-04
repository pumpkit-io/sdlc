## Agent skills

### Issue tracker

Issues live in GitHub Issues on `pumpkit-io/sdlc`, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context: one root `GLOSSARY.md` plus ADRs in `docs/adr/`. See `docs/agents/domain.md`.

## Repo rules

Every skill lives in `skills/<name>/` and ships in the plugin: each one has an entry in `.claude-plugin/plugin.json`'s `skills` array and in the skill-types table in `README.md`. Adding, renaming or removing a skill means updating both. A skill you don't want to ship doesn't belong in this repo.

Each skill is one of three types:

- **Command** (user-invoked): `disable-model-invocation: true` in the frontmatter, plus `policy.allow_implicit_invocation: false` in `agents/openai.yaml`. Only the human can start it.
- **Automatic** (model-invoked): no invocation flag; the `description` carries the trigger phrases the agent matches on.
- **Reference**: `user-invocable: false` in the frontmatter. Reached only by other skills, hidden from the slash menu.

`skills/writing-for-agents/SKILL-MECHANICS.md` explains how to choose. Every skill keeps an `agents/openai.yaml` so the set stays installable in Codex and other Agent Skills harnesses via `npx skills add`.

Portability: the skills must work in every agent the README's support matrix names. Skills load other skills with "Load the `X` skill" and never name a vendor tool. Every sub-agent instruction carries an inline fallback for agents that can't spawn one. A skill that can't degrade declares it in a `compatibility` frontmatter field and its first body line says what to use instead. Changing a skill's type flags, or the hook, means updating the README support matrix. `docs/adr/0002-agent-neutral-skills-single-native-package.md` records why the Claude Code plugin is the only native package.

Run `claude plugin validate .` after touching either manifest. Two warnings are expected: no `version` (on purpose, so installs follow the latest commit) and `CLAUDE.md` at the plugin root (it is repo context, not plugin context).

`hooks/block-dangerous-git.sh` is the always-on git guardrail. When you change it, pipe sample `{"tool_input":{"command":"..."}}` payloads through it and check exit codes: 2 for blocked commands, 0 for allowed ones.

Skills that cannot work without per-repo config point to `/setup-sdlc`; the others degrade silently. See `docs/adr/0001-explicit-setup-pointer-only-for-hard-dependencies.md`.

No em-dashes anywhere in this repo's prose (`SKILL.md` files, docs, `README.md`, ADRs, code comments). Where a sentence reaches for one, rewrite it instead with a comma, colon, period, parentheses, or a conjunction, whichever the sentence actually wants; never do a blind character substitution.

This repo started as a fork of mattpocock/skills and no longer merges from it. To port an upstream improvement, see "Credits and upstream" in `README.md`.
