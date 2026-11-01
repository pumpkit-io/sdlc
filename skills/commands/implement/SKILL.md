---
name: implement
description: "Implement a piece of work from a spec, tickets, or what this session settled."
disable-model-invocation: true
---

Load the `worktrees` skill and resolve the worktree for this work before writing anything. A Ticket or Spec leads to its **Feature worktree** through its Feature branch link, work this session settled stays in the worktree the session already worked in, and a raw idea gets a new worktree. When the feature worktree's lock is busy, stop there with the lock holder's name and the suggestion to run `implement-spec`, the same way in an unattended run.

A Ticket with a `Stacks on:` line is one pull request of a **Stack**, so it gets its own worktree instead of the Feature worktree:

1. Name the predecessor's branch. A `Stacks on:` naming a Ticket means the branch `<feature-slug>-t<ticket>`, where the feature slug is the Slug of the Ticket's Feature branch link (`worktree.sh slug <branch>`). A `Stacks on:` naming the feature branch or `main` means that branch.
2. Run `git fetch origin` and check that the predecessor's branch is on `origin` (`git ls-remote --exit-code --heads origin <branch>`). When it is not, stop and say so: name the branch, the Ticket whose pull request has to be pushed first (for the feature branch, pull request 0, run `implement-spec` or push the feature branch and open that pull request), and that nothing was built.
3. Run `worktree.sh create <feature-slug>-t<ticket> origin/<predecessor branch>` as the `worktrees` skill's Create section says, and work there. Confirm the branch sits on that base before writing anything.

Implement the work from its source:

- **Spec or tickets**: the ones the user names. If commits have landed in their area since they were written, suggest running `refresh-spec` on them first.
- **The conversation**: when the user names no spec or ticket, the work is what this session settled, such as the decisions from `grill-with-docs` or a fix agreed while discussing a bug. Before writing code, post a short brief: the goal, each settled decision, which loose ends are in scope, and the seams you will test at (prefer existing seams, the highest one possible, as few as possible). Then carry on without waiting for a reply. If the session left the goal or a decision open, name what is open and ask instead.

Use /tdd where possible, at the seams the spec or brief agreed.

Load the `code-comments` skill before writing code; every comment you write follows it. When the work builds UI, load the `ui-design` skill and build to the spec's UI Design section, or to the design plan the session settled.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

When `scripts/dev-stack` is executable and the change is reachable over HTTP or UI, read [DEV-STACK-STEP.md](DEV-STACK-STEP.md) once the full suite passes and follow it before the review.

Once done, load the `review-changes` skill to review the work. When you worked from the conversation, hand it the brief as the spec.

Commit your work to the worktree's branch.

Then push, the run's only push, and open a PR when the run finished clean: the full suite and typechecking pass, the dev stack check passed when it ran, the last `review-changes` verdict is `pass` (fix blocking findings and review again), and no decision waits on the user. Load the `pr` skill and open the PR as its "Opening the PR" section says. The PR is always complete, never a draft.

- **A Ticket with `Stacks on:`**: pass the predecessor's branch as the base, the Ticket as the only issue it closes, and the **Stack** for the stack table, read from the Spec's Implementation flow. The Spec closes with the top pull request only, so name it only when this Ticket is the last one in the flow and you run it by hand. Under `implement-spec`, the top pull request closes the Spec instead.
- **Any other work**: no base, so the PR targets the default branch. Name the Spec and Tickets the work came from as the issues it closes (none for work from the conversation).

When the run didn't finish clean, push nothing.

Release this session's worktree lock, as the `worktrees` skill's Release section says. Then load the `run-report` skill and end with the Run report. For a Ticket with `Stacks on:`, list the Stack in merge order, as its Links section says, with this pull request among them.
