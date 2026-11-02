# Third-party services run against Emulators first, safe mode second, bypass flags last

A **Dev stack** has its own **Dev URL** per **Worktree**, and real providers can't follow it: Google wants every redirect URI registered exactly, allows no wildcards and rejects `.localhost` subdomains. Repos have answered ADR 0005's "off or faked by default" with "off", because faking a provider by hand is too much work, and with bypass flags such as `VITE_BYPASS_AUTH=true`. A bypass flag skips the OAuth callback and the session cookie on a per-worktree origin, the code most likely to break, and it can ship switched on. `implement-spec`'s unattended e2e run on the **Stack**'s tip can't reach any flow behind a third-party sign-in.

So a third-party service that `emulate` (vercel-labs/emulate) covers runs against an **Emulator** inside the Dev stack. A service it doesn't cover is switched off by safe mode. A bypass flag in app code is the last resort.

The repo's `scripts/dev-stack` starts and stops its Emulators, as it does its database; skills never call `emulate`, as they never call Portless. Each Dev stack has its own set of Emulators, each on its own route `<service>.emulate.<project>`, prefixed with the **Slug** in a linked Worktree. The contract never uses `emulate --portless`: it hardcodes `https://<service>.emulate.localhost` and registers machine-wide aliases with `--force`, so two Worktrees overwrite each other's routes. The Claude Code hook blocks it.

The app reads every Emulator URL from variables and, in production, refuses every provider URL override, so only the real endpoints exist there.

## Considered Options

- **Safe mode only.** Rejected: unattended runs can't reach flows behind a third-party sign-in.
- **Hand-written fakes per repo.** Rejected: too much work, so nobody writes them.
- **`emulate --portless`.** Rejected: the shared routes above.
- **Real sandbox credentials per Worktree.** Rejected: secrets in every Worktree, and Google's redirect rules.

## Consequences

- Emulators drift from the real APIs. A check against the real provider before release stays the user's job, and the Run report names it for every provider a change touched.
- Emulator state lives in memory and returns to its seed on every `up`, while `down` keeps the app's database. The Emulator's committed config is the only source of the identities and objects the app's own seed refers to.
- Emulators that deliver webhooks need the app's per-worktree address, so their config reads it from variables `up` sets instead of a committed value.
