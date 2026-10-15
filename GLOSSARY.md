# sdlc

A set of agent skills (slash commands and behaviors) shipped as one Claude Code plugin. Skills live in `skills/<name>/` and read per-repo configuration written by `/setup-sdlc`.

## Language

**Issue tracker**:
The tool that hosts a repo's issues: GitHub Issues, GitLab Issues, a local `.scratch/` markdown convention, or similar. Skills like `to-tickets`, `to-spec`, and `triage` read from and write to it.
_Avoid_: backlog manager, backlog backend, issue host

**Issue**:
A single tracked unit of work inside an **Issue tracker**: a bug, task, **Spec**, or **Ticket**.
_Avoid_: ticket (use only for a **Ticket**, or when quoting external systems that call issues tickets)

**Spec**:
An **Issue** that states a feature's problem, solution and user stories, published by `to-spec`.
_Avoid_: PRD, epic

**Ticket**:
An **Issue** that is one vertical slice of a **Spec** or another plan, published by `to-tickets` with the blocking edges to the other **Tickets** it waits on.
_Avoid_: slice, sub-issue (except when naming the tracker feature)

**Stale**:
Said of an **Issue** whose text no longer matches the code: work it asks for already exists, or names and places it cites have changed. An Issue that contradicts a choice the code made differently is not stale; it disagrees with the code, and only the user can say which side is wrong.

**Triage role**:
A canonical state-machine label applied to an **Issue** during triage (e.g. `needs-triage`, `ready-for-agent`). By default the role name is also the label string in the **Issue tracker**; `docs/agents/triage-labels.md`, when present, overrides that per role.

**Slop**:
Agent-written output that reads as generically AI-made: comments that restate the code, inflated or padded prose, decorative or unreasoned UI. Code-level design problems are not slop; they are smells.
_Avoid_: AI-isms, fluff

**Design direction**:
A repo's chosen visual and verbal identity, recorded in `DESIGN.md`. It is frozen: only the user changes it, by asking for an update explicitly.
_Avoid_: style guide, design system (when meaning the direction itself)

**Drift**:
A contradiction between existing UI and the **Design direction**. It is reported, never resolved by the agent, because only the user knows which side is wrong.

## Relationships

- An **Issue tracker** holds many **Issues**
- An **Issue** carries one **Triage role** at a time
- A **Spec** has many **Tickets**; a **Ticket** belongs to at most one **Spec**
- A repo has at most one **Design direction**; **Drift** is always measured against it

## Flagged ambiguities

- "backlog" was previously used to mean both the *tool* hosting issues and the *body of work* inside it. Resolved: the tool is the **Issue tracker**; "backlog" is no longer used as a domain term.
- "backlog backend" / "backlog manager". Resolved: collapsed into **Issue tracker**.
