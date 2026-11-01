# One linear stack of pull requests per Spec

`implement-spec` opens one pull request per **Ticket** instead of one for the whole **Spec**. The pull requests form a single linear **Stack**: each one's base is the branch of the Ticket before it, the first one's base is the feature branch (or `main` when the grilling wrote no docs), and the user merges them first to last. Each pull request then shows only its own Ticket's changes, and `main` stays green after any prefix of the Stack is merged.

Tickets in a **Group** are built in parallel from the same base, then chained in ticket order, each branch merging in its predecessor. This is conflict-free because `to-tickets` puts two Tickets in one Group only when they share no blocking edge and their `Touches:` areas do not overlap. A Group is a barrier: the next one starts when every pull request in the current one has passed review and CI. The Stack assumes merge commits, so stacking merges the lower branch into the upper one and never force-pushes.

## Considered Options

- **Every pull request targets `main` and contains all earlier work.** Rejected: each review reads a cumulative diff, no smaller than the single pull request it replaces, and it only survives merge commits.
- **A per-spec branch that Ticket pull requests target, with one final pull request to `main`.** Rejected: diffs are small, but nothing reaches `main` until the last pull request, and the first-to-last merge order disappears.
- **A true dependency graph, each pull request based on one of its blockers.** Rejected: the other blockers are merged in, so the diff shows changes that belong to other Tickets.
- **One branch per Group for the parallel pull requests to target.** Rejected: the next Group would have no single base that is itself a pull request.

## Consequences

- Parallelism applies to building, not to merging: the PR bases are linear even when the Tickets were built side by side.
- A review fix in one pull request is merged forward into the later pull requests of its Group. Because Groups are barriers, no later Group exists yet.
- Cross-Ticket fixes found by the spec-wide review and e2e run land in an extra top pull request, not in earlier ones.
- Repos that squash or rebase on merge need a different restack recipe, which this decision does not cover.
