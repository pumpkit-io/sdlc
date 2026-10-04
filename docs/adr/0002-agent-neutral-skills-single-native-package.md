# Agent-neutral skills, Claude Code plugin as the only native package

The skills are written for any Agent Skills agent: they load each other by name, every sub-agent step has an inline fallback, and `npx skills add` installs them into `.agents/skills/`, which Codex, Cursor, Gemini CLI, Copilot and OpenCode all read. The Claude Code plugin stays the only native package, and the git guardrail hook ships only there.

## Considered Options

- **Native manifests per agent** (`.codex-plugin/plugin.json`, `.cursor-plugin/plugin.json`, `gemini-extension.json`, a Copilot `plugin.json`), as obra/superpowers ships. Rejected for now: each manifest has to be kept in sync with `skills/`, each agent's hook takes a different JSON payload so the guardrail would need an adapter per agent, and none of these installs could be tested end to end when this was decided.

## Consequences

Revisit when a Codex or Cursor plugin install can be tested end to end, or when users ask for native installs. Adding one is additive: a manifest pointing at `skills/` plus a hook adapter.
