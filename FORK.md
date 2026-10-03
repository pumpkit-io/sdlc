# Fork notes

Upstream: https://github.com/mattpocock/skills (MIT). Forked at `d81f3a183412e71a5b1e84ca21bc1a35eea03a60` on 2026-10-03.

## What this fork changes

- `.claude-plugin/plugin.json`: plugin renamed `sdlc`, ships only the skills listed there, no `version` field (installs follow the latest commit).
- `.claude-plugin/marketplace.json`: marketplace renamed `pumpkit-io`.
- `hooks/`: git guardrails as an always-on plugin hook, adapted from `skills/misc/git-guardrails-claude-code`.
- `user-invocable: false` added to the frontmatter of `grilling`, `codebase-design`, `writing-for-agents`.
- `README.md` rewritten, `FORK.md` added.
- `docs/agents/` and an "Agent skills" block in `AGENTS.md` and `CLAUDE.md`: this repo's own issue-tracker config.
- GitHub Actions disabled for this repo (the upstream release workflow is upstream-only).

Everything else is upstream, unmodified. Upstream's conventions in `AGENTS.md` (docs pages, changesets, ask-matt sync) govern upstream changes; a fork-only change just needs this file updated.

## Syncing from upstream

```bash
git fetch upstream
git switch -c chore/sync-upstream
git merge upstream/main
```

On conflicts: keep ours for `README.md`, `FORK.md`, `.claude-plugin/*`, `hooks/*`; for the three skills listed above, take upstream and re-add the `user-invocable: false` line; take upstream for everything else. Then:

1. `git diff <last synced sha> upstream/main --stat -- skills/` to spot new, renamed or removed skills; update `plugin.json` and the README tables if needed.
2. `claude plugin validate .`
3. Update the SHA and date at the top of this file, push the branch, open a PR, merge it yourself.
