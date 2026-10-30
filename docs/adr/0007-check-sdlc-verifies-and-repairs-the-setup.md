# A `check-sdlc` skill verifies the setup and repairs it with approval

`setup-sdlc` runs once per repo, and afterwards things drift: the harness ships new templates, files get deleted, Portless gets uninstalled, worktrees and dev stacks are left behind. `check-sdlc`, a Command skill, checks every requirement of the harness on this machine and in this repo, prints one table, proposes a fix for each failure, applies the fixes the user approves, and checks again until everything passes or the user stops. Fixes that would change a setup choice (the issue tracker, the design direction) are not offered; it points to the matching `setup-sdlc` section instead.

The checklist lives in one file, `skills/check-sdlc/CHECKS.md`, and `setup-sdlc` runs the same checks as its last step, so setup ends verified rather than with a list of manual steps.

Repo changes from setup or a check land on their own worktree branch. The skill offers a PR by default and fast-forwards the default branch in the **Main checkout** only on the user's explicit yes. That fast-forward is the one write to the main checkout the harness makes, and the guard allows only `--ff-only` merges and pulls there.

## Considered Options

- **Re-running `setup-sdlc` to repair.** Rejected: setup asks every question again, while repairs need only the failures.
