---
name: worktrees
description: "Choose and enter the git worktree a unit of work lives in, and list, finish, sweep or release worktrees. Use before the first file change or commit in a repo whose AGENTS.md has the `### Worktrees` rule, when a skill says to resolve a worktree, or when the user asks to list worktrees, finish one, clean up merged ones or release a lock."
---

Every unit of work lives in its own **Worktree** under the **Main checkout**'s `.claude/worktrees/<slug>/`, and the main checkout itself is the user's: read it, never edit or commit there.

`scripts/worktree.sh` in this skill's folder does the mechanical work: run it with `bash` from any directory inside the repo, worktree or main checkout. It finds the main checkout from git's common directory, so worktrees are never nested. It prints messages on stderr and refuses with exit 1 and a reason; relay its messages to the user as they are.

## Moving the session

If your agent can switch its session into an existing worktree by path, do it with the path `create` printed. Otherwise work there with absolute paths and `git -C <path>`, and run every command from that path. Agents that switch sessions between worktrees often allow it only under `.claude/worktrees/`, which is why the folder is fixed; an agent whose own worktree tool names the branch after the folder needs `git -C <path> branch -m <branch>` afterwards, so prefer creating with the script and switching by path.

To leave a worktree, switch the session back to the main checkout, keeping the worktree on disk, or into another worktree.

## Resolve

The entry point. Every writing skill opens with the step "Load the `worktrees` skill and resolve the worktree for this work before writing anything.", which means this section. Given a **Spec**, a **Ticket**, an idea or nothing, end with the session in one worktree holding its lock, in this order:

1. **Already in a fitting worktree.** When the session is in a linked worktree (its top level differs from `worktree.sh main`) and its branch is the one the work's **Feature branch link** names, or this session already worked there on the same work, stay. This covers a session the agent started in a worktree (in Claude Code, `claude -w`) and a grilling session moving on to `to-spec` or `implement`. Go to step 4.
2. **A Spec or Ticket.** Read its Feature branch link: the line `Branch: <branch>` at the top of the body. A Ticket without one follows its parent Spec's link. With a link, run `worktree.sh create <branch>`: it reuses the branch's worktree, or adds one for a branch that exists locally or on `origin`. A Spec with no link (one written before links existed) gets a new `feat/<slug>` branch as in step 3, and then you write `Branch: <branch>` as the first line of the Spec's body through the issue tracker (`docs/agents/issue-tracker.md`). A Ticket with no Spec is an idea.
3. **An idea, or nothing.** Pick the prefix from the work: `fix/` for a bug, `feat/` for new behaviour, `chore/` for everything else (docs, config, setup, dependencies, a one-line change asked in passing). Name it in two to four lowercase words joined by hyphens, and keep the name for the life of the branch even when the idea changes shape. Run `worktree.sh create <prefix>/<name>`: it fetches `origin` and branches off `origin/<default>`.
4. **Take the lock.** Run `worktree.sh lock <path> "<description>"` before writing anything there. The description is one line naming the skill, the work and when the session started (`implement #42, started 2026-10-30 14:05`); reuse the exact string for every later lock call in this session, since the script treats a matching description as the same session.
   - Exit 3, busy: another session holds a fresh lock. Stop and tell the user who holds it. When the work is one Ticket of a Spec, add that `implement-spec` runs a Spec's Tickets in parallel.
   - Exit 4, stale: the lock was taken over two hours ago, and the worktree has had no file change and no commit for two hours. Ask the user whether to take it over; on yes, run `worktree.sh lock --take-over <path> "<description>"`. In an unattended run, stop with the holder's name instead of asking.
5. **Move the session** into the worktree (above).
6. **Report** one line: `Worktree: <path> (<branch>)`.

`create` stops in two cases, and both end the resolution with its message: the branch is checked out in the main checkout (never switch the user's checkout to free it), or the branch's **Slug** is taken by another worktree. For a slug clash on a new branch, pick a different name; for a linked branch, stop.

### Slug

The branch's last `/` segment, lowercased, every character outside `[a-z0-9-]` turned into `-`, repeats collapsed, leading and trailing `-` trimmed, at most 63 characters: `feat/Login_Flow.v2` gives `login-flow-v2`. This is how Portless names the worktree's **Dev URL**, so the folder and the URL agree. `worktree.sh slug <branch>` prints it.

### Bootstrap

`create` bootstraps every worktree it adds. It copies the gitignored files the repo's `docs/agents/worktrees.md` lists from the main checkout and runs its install command; [WORKTREES-DOC.md](WORKTREES-DOC.md) has the format. Without the doc it copies and installs nothing and says so in one line. When the new branch's `.gitignore` misses the worktrees folder or `.sdlc/`, it adds them in their own commit, `chore: ignore worktrees and session locks`. When the install or that commit fails, `create` stops with the worktree in place, and the next `create` for the branch runs the bootstrap again.

## Create

Resolve without the "stay" step: `worktree.sh create <branch> [<base>]`, then lock, move and report. `<base>` defaults to `origin/<default>`; pass another ref only when the caller names one, such as `implement-spec` basing an **Implementer worktree** on the integration branch.

## Release

Every writing skill closes with the step "Release this session's worktree lock, as the `worktrees` skill's Release section says.": run `worktree.sh release <path>`. It deletes the lock and nothing else.

## List

Run `worktree.sh list` and show it as a table. Each tab-separated row is a worktree's Slug, branch, commits ahead of and behind `origin/<default>`, lock holder (with `(stale)` when it is), lock age, and **Dev stack** status from the repo's `scripts/dev-stack status` (`-` when the repo has no contract).

## Finish

For one worktree the user names, or one this session's work is done in:

1. Leave it first if the session is inside it, and release this session's own lock on it.
2. Run `worktree.sh finish <path>`. It refuses on uncommitted changes (exit 1, listing them), on a lock (exit 3, naming the holder), and on a branch that is neither merged into `origin/<default>` nor pushed (exit 5). Show the user what it listed; a lock held by another session stays.
3. On exit 5, ask the user whether an open PR covers the branch. Only on a clear yes, run `worktree.sh finish <path> --pr-open`.

A worktree whose branch was merged into a branch other than the default, such as an **Implementer worktree** merged into the integration branch, finishes with `worktree.sh finish <path> --merged-into <branch>`: the same refusals, with that branch in place of `origin/<default>`.

Once it passes, the script runs `scripts/dev-stack destroy` when the repo has a contract, removes the worktree, deletes the branch with `git branch -d` and prunes. Neither step forces: a branch `git branch -d` refuses is kept and reported.

## Sweep

Cleanup after PRs merge: run `worktree.sh sweep`. It fetches `origin`, finishes every clean, unlocked worktree whose branch is merged into `origin/<default>`, and prints one line for each worktree it finished or left, with the reason. Relay the lines. A squash-merged branch shows as not merged; offer to finish it if the user says its PR merged.
