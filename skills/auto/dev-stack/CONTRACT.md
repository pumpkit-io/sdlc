# Dev stack contract

The single definition of a repo's **Dev stack contract** (ADR 0005). `setup-sdlc` drafts a repo's contract from it, repo authors implement it, and the `dev-stack` skill calls it. A repo that follows it has two files:

- `scripts/dev-stack`, an executable implementing the six commands below.
- `docs/agents/dev-stack.md`, the **Dev stack doc**, recording the choices listed under [The dev stack doc](#the-dev-stack-doc).

A repo with no app has neither, and no skill mentions a stack there.

## Commands

| Command | Does | Prints | Exit |
|---|---|---|---|
| `up` | Idempotent. Starts the Portless proxy in the recorded mode if it isn't running; starts the stack's **Emulators** and waits for each to answer; starts the stack with its own ports and data; migrates, and seeds the first time; registers the route; waits for the health check up to a timeout. Never prompts. | The **Dev URL** as the last stdout line. Progress and reasons go to stderr. | 0 when healthy; non-zero with a one-line reason on stderr otherwise. |
| `down` | Stops the stack and its Emulators and removes their routes. Keeps its data. | Nothing required. | 0, also when already stopped. |
| `destroy` | `down`, then deletes the stack's data (database, volumes, logs, generated-secrets files, seed marker), starting a stopped shared container to drop its database before the seed marker goes. | Nothing required. | 0, also when nothing is left. |
| `url` | Computes the Dev URL whether or not the stack is running. | The Dev URL. | 0. |
| `status` | Checks the stack's processes and its health URL. | `running` or `stopped`. | 0 for `running`, 3 for `stopped`. |
| `logs [service]` | Shows server output. | With a service: its recent output. Without: one `service: path` line per log file, or recent output of every service. | 0. |

## Rules

- **Location-agnostic.** The script derives everything from `git rev-parse --show-toplevel` and the branch, so the same file runs in the **Main checkout**, a **Feature worktree** and an **Implementer worktree**.
- **Names from the Slug.** Route `<slug>.<project>`, Compose project `<project>-<slug>`, database `<project>_<slug>` (dashes turned into underscores, at most 63 characters). Take the hostname from `portless get <project>`, so the **Slug** is exactly the prefix `portless run` adds in a linked worktree. In the Main checkout Portless adds no prefix: the route, the Compose project and the database are all `<project>`, which no Slug can produce, so a branch ending in `main` gets names of its own. Without Portless installed, `down` and `destroy` still run: they derive the Slug from the branch with the `worktrees` skill's Slug rule.
- **No fixed host ports or container names.** Portless picks the app port (strategy A), or Compose publishes `127.0.0.1::<container port>` and the script reads the port back (strategy B). A container shared on purpose across worktrees, such as strategy A's Postgres, has one fixed name and holds one database per Slug.
- **The app is told its Dev URL** through the variable it reads its public URL from, and derives scheme, cookie flags and absolute URLs from it. Nothing in the app pins `localhost:<port>`.
- **Safe mode by default.** A worker with an outside effect (publishing, mail, payments, webhooks to third parties) either points at an Emulator or is switched off by a variable `up` sets (ADR 0009).
- **Dev credentials only.** The stack runs on throwaway local credentials; nothing in the contract reads production secrets or reaches production services.
- **e2e suites read `E2E_BASE_URL`.** Health checks, Playwright configs and global setups take their base URL from it instead of a pinned port.
- **Only its own route.** `up` registers only this worktree's route. `portless alias <route> <port> --force` is allowed on that route alone; `portless run --force` is never used.
- **Gitignored state.** Pids, logs and markers live under `.sdlc/dev-stack/`. A pid file records the process start time too, and a pid whose process started at another time belongs to someone else: `up` starts its own, and `down` leaves that process alone.

## Emulators

A third-party service that `emulate` covers runs against an Emulator inside the Dev stack; one it doesn't cover is switched off by safe mode; a bypass flag in app code is the last resort (ADR 0009).

- **One set per Dev stack.** Each Emulator runs on its own route `<service>.emulate.<project>`, which Portless prefixes with the Slug in a linked worktree. Emulators are never shared across worktrees.
- **Never `emulate --portless`.** It hardcodes `https://<service>.emulate.localhost` and registers machine-wide aliases with `--force`, so two worktrees overwrite each other's routes. The advertised URL comes from `PORTLESS_URL` (strategy A) or `--base-url` with the `{service}` template (strategy B); the committed config never sets `baseUrl`.
- **URLs through variables.** The app reads each Emulator's URLs from variables `up` sets, up to two per service: browser-facing, which is also the expected token issuer, and server-to-server. The two may be equal.
- **Webhook targets through variables.** An Emulator that delivers webhooks reads its target URL and signing secret from variables `up` sets, through a JS or TS config. The target is the app's server address: its backend route under A, `http://<compose service>:<port>` under B.
- **No overrides in production.** In production the app refuses every provider URL override, so only the real endpoints exist there. It never decides by matching a URL's shape.
- **Started first, answering before the app.** `up` starts every Emulator, waits until each answers a request on its route, then starts the app. `down` stops them and removes their routes; `destroy` also deletes their logs and any generated-secrets file under `.sdlc/dev-stack/`.
- **Pinned exactly.** One emulate version, recorded in the dev stack doc and repeated in the script (A) or the emulate Dockerfile (B).
- **Throwaway config.** The committed config holds throwaway users only and leaves out `oauth_clients` by default, so the Google Emulator skips `client_id` and `redirect_uri` checks. It switches from YAML to a JS or TS config only for per-worktree values: redirect URIs built from the Dev URL, webhook targets. Never `--watch`.
- **State resets whenever `up` starts an Emulator.** Emulators keep state in memory and nothing persists it, so it resets on the first `up` after `down`; an `up` on a running stack leaves its Emulators, and their keys and sessions, alone. The Emulator's config is the only source of the identities and objects the app's own seed refers to. Never store a provider ID created at runtime in the app's seed.
- **No off switch in the contract.** A repo may add its own switch for humans to use a provider's real test mode; every run a skill starts uses Emulators.
- **Extra processes count.** Each Emulator is one more process per Dev stack. The Cap stays as it is, though four Dev stacks with three Emulators each run twelve more Node processes.

## Dev URLs and proxy modes

The proxy is shared by every stack on the machine and runs in one of two modes (ADR 0006), always with `PORTLESS_SYNC_HOSTS=0`:

- **Default**: `portless proxy start -p 1355 --no-tls`. Dev URLs look like `http://login.pumpkit.localhost:1355`.
- **HTTPS upgrade**: HTTPS with HTTP/2 on 443, through `portless trust` and `portless service install` with `sudo`. Dev URLs look like `https://login.pumpkit.localhost`. `up` cannot start this proxy without a password, so when it is down `up` fails with a pointer to the upgrade command.

Every consumer (health checks, `E2E_BASE_URL`, Playwright, the app's own URL variable) accepts both forms. When a proxy already runs in a different mode than the recorded one, `up` uses it as it is and the Dev URL follows it; `check-sdlc` reports the mismatch.

Trust the Portless CA only for `https://` Dev URLs, scoped to the tool: `curl --cacert ~/.portless/ca.pem`, `NODE_EXTRA_CA_CERTS=~/.portless/ca.pem` for Node, or `ignoreHTTPSErrors` in a Playwright context opened for the Dev URL. `PORTLESS_STATE_DIR`, when set, replaces `~/.portless`.

In HTTPS mode, server-side calls to an `https://` Emulator URL, and an Emulator delivering webhooks to an `https://` Dev URL, trust the same CA: `NODE_EXTRA_CA_CERTS` for Node, `SSL_CERT_FILE` or `REQUESTS_CA_BUNDLE` for Python. The alternative is a plain `http://127.0.0.1:<port>` server-to-server URL.

## Strategies

[`scripts/dev-stack.template.sh`](scripts/dev-stack.template.sh) implements both strategies; `setup-sdlc` keeps the block that fits and deletes the other.

- **A, native processes behind `portless run`.** Each service runs as `portless run --name <name> <command>` in the background, which picks a free port, sets `PORT` and `HOST`, and adds the Slug prefix. Extra services get their own route (`api.<project>`), and the app reads their URLs with `portless get`. One shared Postgres container serves a database per Slug. Each Emulator is one `portless run --name <service>.emulate.<project> npx --yes emulate@<pin> start --service <service>`, one process per Emulator because Portless gives each process one `PORT`; the app reads its URLs with `portless get <service>.emulate.<project>`. Before starting them, `up` fetches the package once under a machine-wide lock in npm's cache, which needs Perl (`DEV_STACK_FETCH_LOCK` moves it), and skips the fetch when every Emulator already runs. `down` stops the `portless run` processes, which removes their routes.
- **B, Docker Compose behind `portless alias`.** One Compose project per Slug; the web service publishes `127.0.0.1::<container port>`; `up` reads the host port with `docker compose port` and runs `portless alias <slug>.<project> <port> --force`. `down` is `docker compose down` plus `portless alias --remove <route>`; `destroy` is `docker compose down -v`. Emulators run in one `emulate` service per Compose project, described below.
- **C, no app.** No contract and no dev stack doc.

### Emulators under strategy B

emulate has no official Docker image, so the repo builds one from `emulate.Dockerfile` in the repo root, which pins the version on its `RUN npm install -g emulate@<version>` line:

```dockerfile
FROM node:24-slim
RUN npm install -g emulate@0.13.0
WORKDIR /emulate
ENTRYPOINT ["emulate"]
```

The `emulate` service serves every Emulator from one process on fixed container ports, listens on `0.0.0.0` and publishes each port as `127.0.0.1::<container port>`. emulate gives the services in `--service` order the ports `--port`, `--port` + 1 and so on, so the script's `B_EMULATE_PORT` matches `--port`, the published ports follow the `EMULATORS` order, and the config sets no `port`. The script sets `EMULATE_SERVICES` from `EMULATORS` and `EMULATE_BASE_URL`, the advertised URL with the `{service}` template, on every Compose command:

```yaml
services:
  emulate:
    build: { context: ., dockerfile: emulate.Dockerfile }
    command: ["start", "--host", "0.0.0.0", "--port", "4000", "--service", "${EMULATE_SERVICES}", "--base-url", "${EMULATE_BASE_URL}"]
    environment:
      APP_URL: ${APP_URL}
      STRIPE_WEBHOOK_URL: ${STRIPE_WEBHOOK_URL:-}
      STRIPE_WEBHOOK_SECRET: ${STRIPE_WEBHOOK_SECRET:-}
    volumes: ["./emulate.config.ts:/emulate/emulate.config.ts:ro"]
    ports: ["127.0.0.1::4000", "127.0.0.1::4001"]
  web:
    environment:
      APP_URL: ${APP_URL}
      GOOGLE_ISSUER: ${GOOGLE_ISSUER:-}
      GOOGLE_API_URL: ${GOOGLE_API_URL:-}
      STRIPE_API_URL: ${STRIPE_API_URL:-}
      STRIPE_WEBHOOK_SECRET: ${STRIPE_WEBHOOK_SECRET:-}
```

- `up` starts the `emulate` service first, reads each published port with `docker compose port` and runs `portless alias <slug>.<service>.emulate.<project> <port> --force`, which gives this worktree its own route. It waits until each Emulator answers on its route, then starts the rest of the project.
- The browser-facing URL is the route's URL, which `--base-url` also makes the token issuer. The server-to-server URL is `http://emulate:<container port>` (`b_emulator_api_url <service>`). The discovery document advertises the route, which a container can't reach, so the app configures its token, userinfo and JWKS endpoints explicitly from the server-to-server URL.
- A webhook target is the web service's Compose address, `http://web:<port>/<path>`.
- The `emulate` service gets `APP_URL` as the web service does, so a TS config can build per-worktree redirect URIs from the Dev URL.
- `up` records each alias it registers under `.sdlc/dev-stack/`, and `down` and `destroy` remove those with the web route, so an Emulator dropped from `EMULATORS` between `up` and `down` leaves no alias behind.

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
- Emulate: 0.13.0
- Proxy: HTTP on 1355

## Emulators

Emulator state resets to its config whenever `up` starts an Emulator, so on the first `up` after `down`.

- Google sign-in: route `google.emulate.pumpkit`; `up` sets `GOOGLE_ISSUER` (browser-facing) and `GOOGLE_API_URL` (server-to-server); no webhooks; `GET /o/oauth2/v2/auth` lists the seeded users; `emulate.config.ts` seeds the user `test@example.com`.
- Stripe: route `stripe.emulate.pumpkit`; `up` sets `STRIPE_API_URL`, `STRIPE_WEBHOOK_URL` and `STRIPE_WEBHOOK_SECRET`; delivers webhooks to `http://web:3000/api/webhooks/stripe`; `GET /v1/customers` lists customers; `emulate.config.ts` seeds one product with a monthly price.

## Safe mode

- `PUBLISHER_ENABLED=0`: the publisher worker stays off. X has no Emulator yet, so it is a custom-Emulator candidate.

## HTTPS upgrade

```sh
<the upgrade command, from setup-sdlc's Portless section>
```

## Browsers

Chrome, Firefox, Edge, `curl` and Node's `fetch` resolve `*.localhost` on their own. Safari may not: run `portless hosts sync` once when a Dev URL doesn't resolve there.
~~~

- **Strategy** is `A` or `B` (see [Strategies](#strategies)). **Project** is lowercase `[a-z0-9-]`.
- **e2e** is the command that runs the repo's e2e suite; leave the line out when there is none.
- **Cap** is the most stacks running at once on one machine, 4 by default. A Dev stack's Emulators count with it, not as stacks of their own, though each is one more process.
- **Portless** is the pinned version. **Emulate** is the pinned emulate version; leave the line out when the stack has no Emulators. **Proxy** is the mode, `HTTP on <port>` or `HTTPS on <port>`: `HTTP on 1355` by default, `HTTPS on 443` after the upgrade.
- **Emulators** has one line saying Emulator state resets to its config whenever `up` starts an Emulator, then one bullet per Emulator: its route, the variables `up` sets, its webhook target if any, the path to inspect its state, and what its config seeds. Leave the section out when the stack has none.
- **Safe mode** lists each variable `up` sets and what it turns off, naming each provider emulate doesn't cover as a custom-Emulator candidate, and each covered provider with an outside effect left without an Emulator (declined, or accepted with its issue declined) as one emulate 0.13.0 has an Emulator for.
- **HTTPS upgrade** is present only when the mode is HTTPS.
- `scripts/dev-stack` repeats `PROJECT`, `PROXY_PORT` and `PROXY_TLS` (1 for HTTPS); `check-sdlc` warns when they disagree with the doc. The Emulate version is repeated as `EMULATE_VERSION` in `scripts/dev-stack` under strategy A, and on `emulate.Dockerfile`'s `RUN npm install -g emulate@<version>` line under strategy B.

## Portless 0.15.12 notes

- `portless proxy start --help` starts a proxy instead of printing help. Read `portless --help` for proxy options.
- `portless proxy start` with the flags of the running proxy exits 0; with different flags it exits 1 and leaves the running one alone.
- `portless alias --remove` on a missing route exits 1; `down` ignores that.
- A route registered with `portless alias` outlives its server, which is why `down` removes it.

## emulate 0.13.0 notes

- A built-in Emulator answers its base URL with a JSON 404, and `/_emulate` exists only for custom Emulators. So `up` polls, per Emulator, a path that answers 200 without credentials: `/.well-known/openid-configuration` for Google, `/v1/customers` for Stripe, `/_emulate` for a custom one.
- Its listener binds `127.0.0.1` and takes its port from `PORT`, so `portless run` works with no port flag. It falls back to `PORTLESS_URL` for its advertised URL.
- `--host 0.0.0.0` lets a container publish it. One process serves several services on `--port` upward, in `--service` order, unless the config gives a service its own `port`.
- It finds `emulate.config.{ts,mts,js,mjs,yaml,yml,json}` in the repo root on its own.
- `--generated-secrets-file` refuses a file that exists and leaves it behind on exit, so `up` deletes it before starting the Emulator.
- It delivers webhooks for Stripe, GitHub, Slack, Linear and Resend.
