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

`hooks/block-dangerous-git.sh` is the always-on git and Portless guardrail. `hooks/check-commit-slop.sh` blocks a `git commit` whose added comments fail `hooks/comment-slop.pl`.

Test the hooks with `hooks/test-hooks.sh`. It pipes each case's payload (`tool_input.command` or `tool_input.file_path`, plus `cwd`) through its hook, expects exit 2 for blocked and 0 for allowed, and builds the scratch repos the commit-slop cases need. When you change a hook, add a case for the change to the table and rerun the script. When you change `comment-slop.pl`, also pipe a known-clean history through it (`git diff -U0 <first commit> HEAD | perl hooks/comment-slop.pl` on a repo the skills already cleaned): every finding there is a false positive to fix.

`skills/worktrees/scripts/worktree.sh` does the worktrees skill's git work. After changing it, run `tests/worktrees.sh`, which drives it against scratch repos under `$TMPDIR` and exits non-zero on any failing case.

Skills that cannot work without per-repo config point to `/setup-sdlc`; the others degrade silently. See `docs/adr/0001-explicit-setup-pointer-only-for-hard-dependencies.md`.

All of this repo's prose follows the `prose-style` skill: `SKILL.md` files, docs, `README.md`, ADRs and code comments.

This repo started as a fork of mattpocock/skills and no longer merges from it. To port an upstream improvement, see "Credits and upstream" in `README.md`.
