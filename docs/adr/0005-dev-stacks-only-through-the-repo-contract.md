# Skills reach a running app only through the repo's dev stack contract

Skills never call `docker compose`, `vite`, `uvicorn` or `portless` themselves. They call the repo's **Dev stack contract** (`scripts/dev-stack up|down|destroy|url|status|logs`, described in `docs/agents/dev-stack.md`), and each repo fills those commands for its own stack. This keeps the harness repo-neutral: a Next.js repo, PumpKit's Vite and FastAPI in Docker Compose, and a Rails repo all fit the same commands. A repo with no app has no contract, and every skill skips the running-app steps silently (ADR 0001).

Each **Dev stack** belongs to one **Worktree** and is fully isolated: no fixed host ports or container names, its own database or volume, the app told its own **Dev URL**, and workers that act on the outside world (publishing, mail, payments) off or faked by default. Isolation is the contract's job, not the agent's.

Stacks start on demand, only when the work needs a running app to verify (UI, HTTP behaviour, e2e). `implement` verifies on a stack by default when the contract exists and the change is reachable over HTTP or UI. The skill leaves the stack running and reports its Dev URL, so the user can try it; stacks are destroyed when their worktree is finished. At most four run per machine by default.

Agents never stop the shared proxy or touch another worktree's route. The Claude Code hook blocks `portless proxy stop`, `portless clean`, `portless hosts clean`, `portless service uninstall` and `portless run --force`. It allows `portless prune`, which `portless run` already does on every start, and `portless alias … --force`, which the contract only uses on its own worktree's route name.

`setup-sdlc` drafts `scripts/dev-stack` itself when the repo has no isolation blockers. When it finds blockers (fixed ports, a fixed Compose project name, hard-coded app URLs, a shared database), it does not edit app code: it offers an issue listing them, which then goes through `implement`.

## Considered Options

- **The harness calls Portless directly.** Rejected: it ties every repo to one tool and one stack shape.
- **Traefik with Docker labels as the default.** Rejected: Docker-only, and does not cover apps run as native processes.
- **One long-lived dev stack per agent rather than per worktree.** Rejected: state leaks across branches and migrations diverge.
