---
name: implement-spec
description: "Implement the result of /to-spec and /to-tickets in code."
compatibility: "Needs parallel subagents and git worktrees."
disable-model-invocation: true
---

If your agent can't run subagents in separate git worktrees, stop here: tell the user this skill needs both, and suggest running `implement` on one ticket at a time instead.

You have been provided a spec. This spec should have tickets associated with it, describing how to implement the spec.

The issue tracker should have been provided to you. If not, tell the user to run `/setup-sdlc`.

The goal is the entire spec implemented on a single **integration branch**, pushed once at the end in a PR that closes the spec and every ticket.

The tickets are not a list of steps. They are a **task graph** with blocking relationships between them. This means there is always a **frontier** of tickets which are ready to be grabbed.

Communication to and from subagents should be sparse. Communicate primarily through **context pointers**: to the spec, tickets, research notes, and previous commits. Don't duplicate information already available via pointers.

**Implementer subagents** should be run in the background where possible for maximum concurrency.

## Steps

1. Load the `worktrees` skill and resolve the worktree for this work before writing anything. The Spec's Feature branch link leads to its **Feature worktree**, and that worktree's branch is the integration branch. Hold its lock until the last step. The **feature slug** is that branch's Slug (`worktree.sh slug <integration branch>`); it prefixes every branch below, so two features' implementer branches never share a Slug.

2. Read the spec and tickets to understand the task graph. If commits have landed in their area since they were written, suggest running `refresh-spec` on the spec first.

3. (optional) Use an **exploration subagent** to conduct any exploration required by the tickets - relevant codebase files or external documentation. Ensure the exploration subagent can save files - it should save its markdown notes in a directory outside the repo, accessible by all future subagents. This lets **implementer subagents** focus on implementation rather than exploration.

4. Use **implementer subagents** to implement each ticket, each in its own **Implementer worktree** on branch `<feature-slug>-t<ticket>`, based on the integration branch's tip. Create it with the `worktrees` skill's Create rules (`worktree.sh create <feature-slug>-t<ticket> <integration branch>`) and hand the subagent its path, or use your agent's own subagent worktree isolation when it places worktrees under the Main checkout's `.claude/worktrees/`. Each implementer subagent:
   - takes its own lock on its worktree with its own description, as the `worktrees` skill's Resolve step 4 says;
   - confirms its worktree is on `<feature-slug>-t<ticket>` and based on the integration branch tip before starting, and runs `git checkout -B <feature-slug>-t<ticket> <integration branch>` if not (an isolation worktree starts on a branch named after its folder);
   - loads the `tdd` skill to build the ticket, and the `code-comments` skill for every comment it writes, plus the `ui-design` skill when the ticket builds UI, following the spec's UI Design section;
   - with a stack slot, after its full test suite passes, loads the `dev-stack` skill to verify the ticket at its worktree's **Dev URL**, then runs `scripts/dev-stack destroy` before reporting done; without one, it starts no stack, even where a loaded skill such as `ui-design` asks for one, verifies through its tests and names the missing slot in its report;
   - merges the integration branch tip into its own branch, commits, and releases its lock before reporting done.

   When the repo has a **Dev stack contract** (an executable `scripts/dev-stack`), hand out **stack slots** with the subagents. The free slots are the cap in `docs/agents/dev-stack.md` (default 4) minus the stacks `portless list` shows running, counted the way the `dev-stack` skill's Cap step counts them, minus one held back for the integration stack. Give one slot to each implementer whose ticket is reachable over HTTP or UI, while free slots remain, and take it back when that implementer reports done. The rest get none. Without a contract, implementers get no slots and no stack instructions.

5. Once an **implementer subagent** completes, merge its work to the integration branch with a **merger subagent**. The merger works in its own worktree on branch `<feature-slug>-m<ticket>`, created the same way from the integration branch tip and locked the same way: it merges the implementer branch there, resolves any conflicts, runs the tests, then fast-forwards the integration branch in the feature worktree (`git -C <feature worktree> merge --ff-only <feature-slug>-m<ticket>`) and releases its lock. Run mergers one at a time, so each fast-forward lands.

6. If this changes the **frontier** of available tickets, kick off more **implementer subagents** to work on the new tickets. This allows for maximum concurrency.

7. Once all tickets are complete, load the `review-changes` skill and run it on the integration branch. Fix all issues raised by the code review in a single **implementer subagent** on branch `<feature-slug>-review`, created and merged the same way.

8. When the repo has a Dev stack contract, run e2e on the integration stack once the review fixes are merged: load the `dev-stack` skill in the feature worktree, bring up its stack, and run the doc's e2e command in full with `E2E_BASE_URL=<Dev URL>` (or the skill's next strongest check when the repo has no e2e suite). Fix failures the way step 7 fixes review findings, then run it again. Leave the integration stack running.

9. Push the integration branch, its only push, and open a PR when the run finished clean: every ticket merged, the full suite passes on the integration branch, the e2e run passed when step 8 ran, the `review-changes` verdict is `pass` (run it again after the step 7 fixes merge), and no decision waits on the user. When the run didn't finish clean, push nothing, leave the tickets open and end the report with what blocks it. Otherwise load the `pr` skill and open the PR as its "Opening the PR" section says, naming the spec and every ticket as the issues it closes. When no PR opens, or the issue tracker doesn't live on the code host (a local tracker), resolve each ticket the way the issue tracker closes work.

10. Finish every implementer and merger worktree through the `worktrees` skill's Finish rules, with `worktree.sh finish <path> --merged-into <integration branch>`: their branches are merged into the integration branch, not yet into the default branch. In a repo with a contract, the script destroys each one's Dev stack before it removes the worktree. Relay any worktree it leaves and why.

11. Report the integration branch, the feature worktree's path and the PR link, then release this session's worktree lock, as the `worktrees` skill's Release section says. When step 8 ran, the report ends with the integration stack's `Dev URL:` and `Checked there:` lines.
