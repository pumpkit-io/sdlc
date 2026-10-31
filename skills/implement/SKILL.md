---
name: implement
description: "Implement a piece of work from a spec, tickets, or what this session settled."
disable-model-invocation: true
---

Load the `worktrees` skill and resolve the worktree for this work before writing anything. A Ticket or Spec leads to its **Feature worktree** through its Feature branch link, work this session settled stays in the worktree the session already worked in, and a raw idea gets a new worktree. When the feature worktree's lock is busy, stop there with the lock holder's name and the suggestion to run `implement-spec`, the same way in an unattended run.

Implement the work from its source:

- **Spec or tickets**: the ones the user names. If commits have landed in their area since they were written, suggest running `refresh-spec` on them first.
- **The conversation**: when the user names no spec or ticket, the work is what this session settled, such as the decisions from `grill-with-docs` or a fix agreed while discussing a bug. Before writing code, post a short brief: the goal, each settled decision, which loose ends are in scope, and the seams you will test at (prefer existing seams, the highest one possible, as few as possible). Then carry on without waiting for a reply. If the session left the goal or a decision open, name what is open and ask instead.

Use /tdd where possible, at the seams the spec or brief agreed.

Load the `code-comments` skill before writing code; every comment you write follows it. When the work builds UI, load the `ui-design` skill and build to the spec's UI Design section, or to the design plan the session settled.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

When `scripts/dev-stack` is executable and the change is reachable over HTTP or UI, read [DEV-STACK-STEP.md](DEV-STACK-STEP.md) once the full suite passes and follow it before the review.

Once done, load the `review-changes` skill to review the work. When you worked from the conversation, hand it the brief as the spec.

Commit your work to the worktree's branch.

Then push, the run's only push, and open a PR when the run finished clean: the full suite and typechecking pass, the dev stack check passed when it ran, the last `review-changes` verdict is `pass` (fix blocking findings and review again), and no decision waits on the user. Load the `pr` skill and open the PR as its "Opening the PR" section says, naming the Spec and Tickets the work came from as the issues it closes. When the run didn't finish clean, push nothing and end the report with what blocks it.

Close by naming the worktree path, the branch and the PR link, then release this session's worktree lock, as the `worktrees` skill's Release section says.
