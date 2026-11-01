# The dev stack step

The repo has a **Dev stack contract** and the change is reachable over HTTP or UI. Unit and integration tests still run on their own, with no **Dev stack**; this step comes after the full suite passes.

1. Load the `dev-stack` skill and bring up this worktree's stack.
2. Verify the change at its **Dev URL** with the strongest check the skill lists.
3. Leave the stack running for the user.

The closing report ends with the `dev-stack` skill's `Dev URL:` and `Checked there:` lines.
