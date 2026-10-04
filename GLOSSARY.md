# sdlc

A set of agent skills (slash commands and behaviors) shipped as one Claude Code plugin. Skills live in `skills/<name>/` and read per-repo configuration written by `/setup-sdlc`.

## Language

**Issue tracker**:
The tool that hosts a repo's issues: GitHub Issues, GitLab Issues, a local `.scratch/` markdown convention, or similar. Skills like `to-tickets`, `to-spec`, and `triage` read from and write to it.
_Avoid_: backlog manager, backlog backend, issue host

**Issue**:
A single tracked unit of work inside an **Issue tracker**: a bug, task, spec, or slice produced by `to-tickets`.
_Avoid_: ticket (use only when quoting external systems that call them tickets, or for a slice produced by `to-tickets`)

**Triage role**:
A canonical state-machine label applied to an **Issue** during triage (e.g. `needs-triage`, `ready-for-agent`). By default the role name is also the label string in the **Issue tracker**; `docs/agents/triage-labels.md`, when present, overrides that per role.

## Relationships

- An **Issue tracker** holds many **Issues**
- An **Issue** carries one **Triage role** at a time

## Flagged ambiguities

- "backlog" was previously used to mean both the *tool* hosting issues and the *body of work* inside it. Resolved: the tool is the **Issue tracker**; "backlog" is no longer used as a domain term.
- "backlog backend" / "backlog manager". Resolved: collapsed into **Issue tracker**.
