---
name: dev-stack
description: Run this worktree's copy of the app through the repo's dev stack contract, verify a change on it, and report its Dev URL. Use when the user asks to run or start the app, open it in the browser, or for its URL, or when another skill needs a running app to verify a change.
---

# Dev stack

Bring up the current **Worktree**'s **Dev stack**, check the work at its **Dev URL** with the strongest check available, and leave it running for the user. Every action on the stack goes through the repo's **Dev stack contract**, whose commands and rules are defined in [`CONTRACT.md`](CONTRACT.md).

## 1. Read the dev stack doc

Read `docs/agents/dev-stack.md`. It names the contract's entry point (`scripts/dev-stack`), the cap, the health URL, the e2e command and the browser notes.

Without the doc, say once: "This repo has no dev stack doc; the Dev stack section of `setup-sdlc` adds one." Then carry on with the rest of the work without a running app, and skip the steps below.

Done when you know the entry point and the cap, or you have said the line above.

## 2. Up

1. **Cap.** The cap is the doc's (default 4), or a smaller one the calling skill passes. Run `portless list` and count the running stacks on this machine: each route is one stack, and routes sharing a slug and a project (a stack's extra services) count once. When this worktree's own route is among them, `up` takes no new slot. At the cap, name the running stacks by route. With a user present, ask whether to continue without a running app or wait while they stop one. In an unattended run, skip the running-app steps and note: "Dev stack skipped: <n> of <cap> stacks running (<routes>)."
2. **Start.** Run `scripts/dev-stack up` from the worktree's top level, with no input attached. It is idempotent: when the stack already runs, it only prints the URL. Take the Dev URL from the last line of its stdout.
3. **On failure**, read the reason `up` printed on stderr, then `scripts/dev-stack logs`, before changing anything.

Done when `scripts/dev-stack status` prints `running`, or the run is skipped with its note.

## 3. Verify

Check the change at the Dev URL with the strongest check available, in this order:

1. The repo's e2e suite (the doc's e2e command) with `E2E_BASE_URL=<Dev URL>`, narrowed to the specs that cover the change.
2. A browser tool your agent has: open the Dev URL and exercise the change as a user would.
3. A headless browser script (Playwright, for one) run against the Dev URL.
4. HTTP requests (`curl`) to each route the change touches, checking status codes and bodies.

Take a screenshot of each UI change at the Dev URL when a browser tool or headless script is available, and save it under `.sdlc/dev-stack/screenshots/`.

For an `https://` Dev URL, trust the Portless CA as `CONTRACT.md` describes; an `http://…:1355` URL needs nothing.

When a check fails, read `scripts/dev-stack logs` (it lists one log per service) and then `scripts/dev-stack logs <service>` before forming a theory. Quote only the lines that carry the signal, with secrets written as `<REDACTED>`.

Done when every change reachable over HTTP or UI has been checked at the Dev URL, each UI change has its screenshot where one could be taken, and every failure has its log lines.

## 4. Report

Leave the stack running. End the report with these two lines:

```
Dev URL: <Dev URL> (running)
Checked there: <checks run and their result, screenshot paths>
```

## Boundaries

The stack is this worktree's; everything else on the machine belongs to other sessions.

- Reach the stack only through this worktree's `scripts/dev-stack`. Other worktrees' stacks are read through `portless list` and left alone: their contracts are theirs to run.
- Leave the Portless proxy as it is. `up` starts it when it is down; stopping, restarting or reconfiguring it is the user's call, and a mode that differs from the doc's is reported, not fixed.
- Register and re-point only this worktree's own route. Another worktree's route is never taken over with `--force`.
- Run the stack on the contract's dev credentials and safe-mode settings. Production credentials and services stay out of it.
- `down` and `destroy` run only when the user or the calling skill asks; finishing a worktree destroys its stack.
