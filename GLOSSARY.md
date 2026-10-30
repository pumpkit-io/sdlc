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

### Worktrees and dev stacks

**Main checkout**:
A repo's original clone. It belongs to the user, on whatever branch the user has checked out: agents read it but never edit files or commit in it.
_Avoid_: main worktree, root checkout

**Worktree**:
A git linked worktree holding one unit of work on its own branch, created from the **Main checkout**. A **Feature worktree** holds a feature branch, which is also the integration branch when `implement-spec` runs; an **Implementer worktree** holds one **Ticket**'s branch while `implement-spec` builds it.
_Avoid_: workspace, sandbox, checkout (for a linked worktree)

**Slug**:
The short name that identifies a **Worktree** within its repo and prefixes its **Dev URL**. Two worktrees of one repo never share a slug.

**Worktree lock**:
The marker saying a session is working in a **Worktree**. A worktree has at most one active session; a lock with no file change and no commit for two hours is stale.
_Avoid_: claim, lease

**Feature branch link**:
The line on a **Spec**, copied onto each of its **Tickets**, naming the feature branch the work lives on. It is how a fresh session finds the **Feature worktree** for that work.

**Dev stack**:
One running copy of a repo's app for one **Worktree**, with its own processes, its own data and its own **Dev URL**, and no effect on the outside world.
_Avoid_: instance, environment, dev server (when meaning the whole stack)

**Dev URL**:
The stable address a **Dev stack** answers at, derived from the **Slug** and the project name. It carries no port of its own (at most the one port every stack on the machine shares), and it never changes for a branch.
_Avoid_: preview URL, localhost link

**Dev stack contract**:
The fixed set of commands (`up`, `down`, `destroy`, `url`, `status`, `logs`) through which skills start, address and stop a repo's **Dev stack**. The harness fixes the commands; each repo implements them its own way.
_Avoid_: dev script, launcher

## Relationships

- An **Issue tracker** holds many **Issues**
- An **Issue** carries one **Triage role** at a time
- A **Spec** has many **Tickets**; a **Ticket** belongs to at most one **Spec**
- A repo has at most one **Design direction**; **Drift** is always measured against it
- A **Main checkout** has many **Worktrees**; a **Worktree** has one **Slug**, at most one **Dev stack** and at most one active **Worktree lock**
- A **Dev stack** has one **Dev URL** and is started and stopped only through its repo's **Dev stack contract**
- A **Spec** has one **Feature branch link**, which leads to one **Feature worktree**; each **Implementer worktree** branches from a **Feature worktree**

## Flagged ambiguities

- "backlog" was previously used to mean both the *tool* hosting issues and the *body of work* inside it. Resolved: the tool is the **Issue tracker**; "backlog" is no longer used as a domain term.
- "backlog backend" / "backlog manager". Resolved: collapsed into **Issue tracker**.
- "instance" for a running copy of the app. Resolved: the term is **Dev stack**, because adopting repos already use "instance" for their own things (PumpKit's **Instance** is a self-hosted deployment).
