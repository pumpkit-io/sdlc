# Dev stack contract

The single definition of a repo's **Dev stack contract** (ADR 0005). `setup-sdlc` drafts a repo's contract from it, repo authors implement it, and the `dev-stack` skill calls it. A repo that follows it has two files:

- `scripts/dev-stack`, an executable implementing the six commands below.
- `docs/agents/dev-stack.md`, the **Dev stack doc**, recording the choices listed under [The dev stack doc](#the-dev-stack-doc).

A repo with no app has neither, and no skill mentions a stack there.

## Commands

| Command | Does | Prints | Exit |
|---|---|---|---|
| `up` | Idempotent. Starts the Portless proxy in the recorded mode if it isn't running; starts the stack with its own ports and data; migrates, and seeds the first time; registers the route; waits for the health check up to a timeout. Never prompts. | The **Dev URL** as the last stdout line. Progress and reasons go to stderr. | 0 when healthy; non-zero with a one-line reason on stderr otherwise. |
| `down` | Stops the stack and removes its route. Keeps its data. | Nothing required. | 0, also when already stopped. |
| `destroy` | `down`, then deletes the stack's data (database, volumes, logs, seed marker), starting a stopped shared container to drop its database before the seed marker goes. | Nothing required. | 0, also when nothing is left. |
| `url` | Computes the Dev URL whether or not the stack is running. | The Dev URL. | 0. |
| `status` | Checks the stack's processes and its health URL. | `running` or `stopped`. | 0 for `running`, 3 for `stopped`. |
| `logs [service]` | Shows server output. | With a service: its recent output. Without: one `service: path` line per log file, or recent output of every service. | 0. |

## Rules

- **Location-agnostic.** The script derives everything from `git rev-parse --show-toplevel` and the branch, so the same file runs in the **Main checkout**, a **Feature worktree** and an **Implementer worktree**.
- **Names from the Slug.** Route `<slug>.<project>`, Compose project `<project>-<slug>`, database `<project>_<slug>` (dashes turned into underscores, at most 63 characters). Take the hostname from `portless get <project>`, so the **Slug** is exactly the prefix `portless run` adds in a linked worktree. In the Main checkout Portless adds no prefix: the route, the Compose project and the database are all `<project>`, which no Slug can produce, so a branch ending in `main` gets names of its own. Without Portless installed, `down` and `destroy` still run: they derive the Slug from the branch with the `worktrees` skill's Slug rule.
- **No fixed host ports or container names.** Portless picks the app port (strategy A), or Compose publishes `127.0.0.1::<container port>` and the script reads the port back (strategy B). A container shared on purpose across worktrees, such as strategy A's Postgres, has one fixed name and holds one database per Slug.
- **The app is told its Dev URL** through the variable it reads its public URL from, and derives scheme, cookie flags and absolute URLs from it. Nothing in the app pins `localhost:<port>`.
- **Safe mode by default.** `up` sets the variables that turn off, or point at fakes, every worker with an outside effect: publishing, mail, payments, webhooks to third parties.
- **Dev credentials only.** The stack runs on throwaway local credentials; nothing in the contract reads production secrets or reaches production services.
- **e2e suites read `E2E_BASE_URL`.** Health checks, Playwright configs and global setups take their base URL from it instead of a pinned port.
- **Only its own route.** `up` registers only this worktree's route. `portless alias <route> <port> --force` is allowed on that route alone; `portless run --force` is never used.
- **Gitignored state.** Pids, logs and markers live under `.sdlc/dev-stack/`. A pid file records the process start time too, and a pid whose process started at another time belongs to someone else: `up` starts its own, and `down` leaves that process alone.

## Dev URLs and proxy modes

The proxy is shared by every stack on the machine and runs in one of two modes (ADR 0006), always with `PORTLESS_SYNC_HOSTS=0`:

- **Default**: `portless proxy start -p 1355 --no-tls`. Dev URLs look like `http://login.pumpkit.localhost:1355`.
- **HTTPS upgrade**: HTTPS with HTTP/2 on 443, through `portless trust` and `portless service install` with `sudo`. Dev URLs look like `https://login.pumpkit.localhost`. `up` cannot start this proxy without a password, so when it is down `up` fails with a pointer to the upgrade command.

Every consumer (health checks, `E2E_BASE_URL`, Playwright, the app's own URL variable) accepts both forms. When a proxy already runs in a different mode than the recorded one, `up` uses it as it is and the Dev URL follows it; `check-sdlc` reports the mismatch.

Trust the Portless CA only for `https://` Dev URLs, scoped to the tool: `curl --cacert ~/.portless/ca.pem`, `NODE_EXTRA_CA_CERTS=~/.portless/ca.pem` for Node, or `ignoreHTTPSErrors` in a Playwright context opened for the Dev URL. `PORTLESS_STATE_DIR`, when set, replaces `~/.portless`.

## Strategies

[`scripts/dev-stack.template.sh`](scripts/dev-stack.template.sh) implements both strategies; `setup-sdlc` keeps the block that fits and deletes the other.

- **A, native processes behind `portless run`.** Each service runs as `portless run --name <name> <command>` in the background, which picks a free port, sets `PORT` and `HOST`, and adds the Slug prefix. Extra services get their own route (`api.<project>`), and the app reads their URLs with `portless get`. One shared Postgres container serves a database per Slug. `down` stops the `portless run` processes, which removes their routes.
- **B, Docker Compose behind `portless alias`.** One Compose project per Slug; the web service publishes `127.0.0.1::<container port>`; `up` reads the host port with `docker compose port` and runs `portless alias <slug>.<project> <port> --force`. `down` is `docker compose down` plus `portless alias --remove <route>`; `destroy` is `docker compose down -v`.
- **C, no app.** No contract and no dev stack doc.

## The dev stack doc

`setup-sdlc` writes `docs/agents/dev-stack.md` in this format. `check-sdlc` reads the field lines by their exact `- <Field>: ` prefix, so keep each on one line.

~~~markdown
# Dev stack

- Entry point: `scripts/dev-stack`
- Strategy: B
- Project: `pumpkit`
- Health URL: `/health`
- e2e: `npm run e2e`
- Cap: 4
- Portless: 0.15.12
- Proxy: HTTP on 1355

## Safe mode

- `VITE_BYPASS_AUTH=true`: skips the real sign-in provider.
- `PUBLISHER_ENABLED=0`: the publisher worker stays off.

## HTTPS upgrade

```sh
<the upgrade command, from setup-sdlc's Portless section>
```

## Browsers

Chrome, Firefox, Edge, `curl` and Node's `fetch` resolve `*.localhost` on their own. Safari may not: run `portless hosts sync` once when a Dev URL doesn't resolve there.
~~~

- **Strategy** is `A` or `B` (see [Strategies](#strategies)). **Project** is lowercase `[a-z0-9-]`.
- **e2e** is the command that runs the repo's e2e suite; leave the line out when there is none.
- **Cap** is the most stacks running at once on one machine, 4 by default.
- **Portless** is the pinned version. **Proxy** is the mode, `HTTP on <port>` or `HTTPS on <port>`: `HTTP on 1355` by default, `HTTPS on 443` after the upgrade.
- **Safe mode** lists each variable `up` sets and what it turns off.
- **HTTPS upgrade** is present only when the mode is HTTPS.
- `scripts/dev-stack` repeats `PROJECT`, `PROXY_PORT` and `PROXY_TLS` (1 for HTTPS); `check-sdlc` warns when they disagree with the doc.

## Portless 0.15.12 notes

- `portless proxy start --help` starts a proxy instead of printing help. Read `portless --help` for proxy options.
- `portless proxy start` with the flags of the running proxy exits 0; with different flags it exits 1 and leaves the running one alone.
- `portless alias --remove` on a missing route exits 1; `down` ignores that.
- A route registered with `portless alias` outlives its server, which is why `down` removes it.
