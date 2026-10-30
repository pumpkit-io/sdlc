---
name: implement-spec
description: "Implement the result of /to-spec and /to-tickets in code."
compatibility: "Needs parallel subagents and git worktrees."
disable-model-invocation: true
---

If your agent can't run subagents in separate git worktrees, stop here: tell the user this skill needs both, and suggest running `implement` on one ticket at a time instead.

You have been provided a spec. This spec should have tickets associated with it, describing how to implement the spec.

The issue tracker should have been provided to you. If not, tell the user to run `/setup-sdlc`.

The goal is the entire spec implemented on a single **integration branch**, with every ticket resolved the way the issue tracker closes work.

The tickets are not a list of steps. They are a **task graph** with blocking relationships between them. This means there is always a **frontier** of tickets which are ready to be grabbed.

Communication to and from subagents should be sparse. Communicate primarily through **context pointers**: to the spec, tickets, research notes, and previous commits. Don't duplicate information already available via pointers.

**Implementer subagents** should be run in the background where possible for maximum concurrency.

## Steps

1. Load the `worktrees` skill and resolve the worktree for this work before writing anything. The Spec's Feature branch link leads to its **Feature worktree**, and that worktree's branch is the integration branch. Hold its lock until the last step. The **feature slug** is that branch's Slug (`worktree.sh slug <integration branch>`); it prefixes every branch below, so two features' implementer branches never share a Slug.

2. Read the spec and tickets to understand the task graph. If commits have landed in their area since they were written, suggest running `refresh-spec` on the spec first.

3. (optional) Use an **exploration subagent** to conduct any exploration required by the tickets - relevant codebase files or external documentation. Ensure the exploration subagent can save files - it should save its markdown notes in a directory outside the repo, accessible by all future subagents. This lets **implementer subagents** focus on implementation rather than exploration.

4. If the issue tracker closes work through PRs, or the user asks for one, open a draft PR from the integration branch after the first merge in step 6 (a branch with no commits ahead of main can't open one), marked as closing the spec and tickets.

5. Use **implementer subagents** to implement each ticket, each in its own **Implementer worktree** on branch `<feature-slug>-t<ticket>`, based on the integration branch's tip. Create it with the `worktrees` skill's Create rules (`worktree.sh create <feature-slug>-t<ticket> <integration branch>`) and hand the subagent its path, or use your agent's own subagent worktree isolation when it places worktrees under the Main checkout's `.claude/worktrees/`. Each implementer subagent:
   - takes its own lock on its worktree with its own description, as the `worktrees` skill's Resolve step 4 says;
   - confirms its worktree is on `<feature-slug>-t<ticket>` and based on the integration branch tip before starting, and runs `git checkout -B <feature-slug>-t<ticket> <integration branch>` if not (an isolation worktree starts on a branch named after its folder);
   - loads the `tdd` skill to build the ticket, and the `code-comments` skill for every comment it writes, plus the `ui-design` skill when the ticket builds UI, following the spec's UI Design section;
   - merges the integration branch tip into its own branch, commits, and releases its lock before reporting done.

6. Once an **implementer subagent** completes, merge its work to the integration branch with a **merger subagent**. The merger works in its own worktree on branch `<feature-slug>-m<ticket>`, created the same way from the integration branch tip and locked the same way: it merges the implementer branch there, resolves any conflicts, runs the tests, then fast-forwards the integration branch in the feature worktree (`git -C <feature worktree> merge --ff-only <feature-slug>-m<ticket>`) and releases its lock. Run mergers one at a time, so each fast-forward lands.

7. If this changes the **frontier** of available tickets, kick off more **implementer subagents** to work on the new tickets. This allows for maximum concurrency.

8. Once all tickets are complete, load the `review-changes` skill and run it on the integration branch. Fix all issues raised by the code review in a single **implementer subagent** on branch `<feature-slug>-review`, created and merged the same way.

9. If a draft PR exists, mark it ready for review. Otherwise, resolve each ticket the way the issue tracker closes work.

10. Finish every implementer and merger worktree through the `worktrees` skill's Finish rules, with `worktree.sh finish <path> --merged-into <integration branch>`: their branches are merged into the integration branch, not yet into the default branch. Relay any worktree it leaves and why.

11. Report the integration branch and the feature worktree's path, then release this session's worktree lock, as the `worktrees` skill's Release section says.
