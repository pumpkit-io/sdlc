# Sections G and H: Portless and the dev stack

Only for a repo with a runnable app. Section G sets up Portless on this machine and runs as it goes, from the main checkout, because nothing it changes lives in the repo. Section H drafts the repo's **Dev stack** files for the Process's step 3 (Confirm and edit). The contract both serve is `dev-stack/CONTRACT.md`, in the skill folder alongside this one: read it before Section H.

## Section G: Portless on this machine

Every step checks first and skips when its check already passes, so a second run changes nothing. Run `sudo` only as `sudo -n`, and never run the commands the guardrail blocks (`portless proxy stop`, `portless clean`, `portless hosts clean`, `portless service uninstall`, `portless run --force`): hand those to the user.

**Already configured.** When Explore found Portless 0.15.12 installed, a proxy answering and `portless doctor` passing, say one line, `Portless: already configured (0.15.12, <mode>)`, record that mode as it runs, and go to Section H. This holds when another repo set the machine up, whatever mode it chose.

Otherwise ask one question:

> Set up Portless 0.15.12 here, with its proxy on plain HTTP, port 1355, and no `sudo`? (recommended: **yes**)

On **no**, skip to Section H and record the default mode; `check-sdlc` lists the setup as missing. On **yes**:

1. **Node.** Portless 0.15.12 needs Node 24 or later. When `node` is missing or older, ask before installing it with the platform's package manager: `brew install node` on macOS, `winget install OpenJS.NodeJS` on Windows, the distribution's package on Linux. A Linux install needs `sudo`: run it when `sudo -n true` succeeds, otherwise give the user the command and wait.
2. **Install.** `npm install -g portless@0.15.12`, unless `portless --version` already prints `0.15.12`. When the global prefix (`npm config get prefix`) isn't writable by the user, set a user-owned one first: `npm config set prefix ~/.npm-global`, then add `~/.npm-global/bin` to `PATH` in the user's shell profile and name the file you changed. Check with `portless --version`.
3. **HTTPS offer**, once, before the proxy starts:

   > Dev URLs will look like `http://<slug>.<project>.localhost:1355`. HTTPS with HTTP/2 on port 443 drops the port and speeds up Vite's first page load, for one `sudo` command. Upgrade? (recommended: **no**, keep HTTP)

   On **yes** with no proxy running and `sudo -n true` succeeding, run the upgrade yourself in place of step 4, with each `sudo` as `sudo -n` and without the leading `portless proxy stop`. Otherwise give the user the command below to paste after setup, and carry on with step 4. Either way the recorded mode is `HTTPS on 443`, and the command goes into the dev stack doc.

   ```sh
   portless proxy stop; sudo PORTLESS_SYNC_HOSTS=0 portless proxy start -p 443 --https && portless trust && sudo PORTLESS_SYNC_HOSTS=0 portless service install
   ```

   The service install is part of it: a proxy started with `sudo` doesn't survive a reboot, and a contract's `up` can't restart one without a password.
4. **Proxy.** When a proxy already answers, leave it as it is and record the mode it runs in. Otherwise start the default with hosts sync off, since syncing `/etc/hosts` needs root on every route change:

   ```sh
   PORTLESS_SYNC_HOSTS=0 portless proxy start -p 1355 --no-tls </dev/null
   ```

5. **Verify.** Run `portless doctor`, then the smoke route as the `portless.smoke` row of `check-sdlc/CHECKS.md` describes. Report each in one line; on a failure, quote the failing lines and carry on, since `check-sdlc` reports it again at the end.

Done when Portless prints `0.15.12`, a proxy answers (or the user holds the upgrade command), and you have the version and mode to record.

## Section H: Dev stack

1. **Strategy.** Recommend **B** (Docker Compose behind `portless alias`) when the app already runs under Compose in development, **A** (native processes behind `portless run`) when it runs as native dev servers. Ask one question, with the reason in one line:

   > Run each worktree's stack with strategy <A or B>? (recommended: **<A or B>**)

2. **Emulators.** Skip this step without a question when Explore found no covered provider. Otherwise ask one question, naming the covered providers:

   > Run <providers> against Emulators in each worktree's Dev stack, pinned to emulate 0.13.0? (recommended: **yes**)

   Each accepted provider gets an Emulator in the drafts below. Every other provider gets a Safe mode bullet in the doc instead: a provider emulate doesn't cover is named there as a custom-Emulator candidate, and a covered provider the user declined is named as having an Emulator in emulate 0.13.0. Setup builds no custom Emulator. On **yes** under strategy A, fetch the package once from the main checkout so the first `up` doesn't spend its health timeout on the download: `npx --yes emulate@0.13.0 --version`. Report it in one line; a failure only means the first `up` downloads it.
3. **The dev stack doc.** Draft `docs/agents/dev-stack.md` in the format under "The dev stack doc" in `CONTRACT.md`: entry point `scripts/dev-stack`; the strategy; the project, from the repo's name in lowercase `[a-z0-9-]`; the health URL path (`/` when the app has no health endpoint); the e2e command, when there is a suite; cap 4; Portless 0.15.12 and the mode from Section G; one Safe mode bullet for each worker with an outside effect, naming the variable `up` sets and what it turns off; the HTTPS upgrade command, only in HTTPS mode; and the browser notes as the format gives them. With accepted Emulators, also the `- Emulate: 0.13.0` line after `- Portless:`, and a `## Emulators` section: the line that Emulator state resets to its config whenever `up` starts an Emulator, then one bullet per Emulator with its route `<service>.emulate.<project>`, the variables `up` sets (the ones Explore found the app reads), its webhook target if it delivers webhooks, the path that shows its state, and what its config seeds; with blockers, these bullets describe the Emulators the issue's work delivers. Each provider left to safe mode gets the Safe mode bullet step 2 gives it. When the doc exists, keep it and propose only the lines the format lacks.
4. **Contract or issue.** Which one depends on Explore's isolation blockers, counting the discovery-document-only sign-in blocker only under strategy B.
   - **No blockers**: draft `scripts/dev-stack` from `dev-stack/scripts/dev-stack.template.sh`. Keep the chosen strategy's block and delete the other; set `PROJECT`, `STRATEGY`, `PROXY_PORT`, `PROXY_TLS` (1 for HTTPS), `HEALTH_PATH` and `APP_URL_VAR` to the doc's values; fill every TODO from the repo (the dev server command, migrations and seed, the Compose file, web service and port, the safe-mode exports) and delete each TODO line once it is filled. With accepted Emulators, also draft the Emulator block below. It all goes to the Process's step 3 (Confirm and edit) for approval.
   - **Blockers**: draft no script and change no app code. Ask one question:

     > Open one issue, "Make the dev stack worktree-safe", listing each blocker? (recommended: **yes**)

     On **yes**, draft its body for the Process's step 3: each blocker with its file and the change the contract needs, the chosen strategy, and that `implement` then drafts `scripts/dev-stack` from the `dev-stack` skill's template and `CONTRACT.md`. It is filed in the Process's step 4 (Write). An app that can't be pointed at an Emulator adds, for each such provider:
     - the change the app needs: read the provider's browser-facing URL (also the token issuer) and its server-to-server URL from variables in place of the hard-coded URL, the pinned issuer or the bypass flag; under strategy B, an app that finds its token, userinfo and JWKS endpoints only through the OIDC discovery document also configures them explicitly from the server-to-server URL, since the document advertises a route the container can't reach;
     - the production guard: in production the app refuses every provider URL override, without matching a URL's shape;
     - with an e2e suite, that e2e sign-in drives the Emulator's sign-in page in place of the bypass;
     - that `implement` also drafts the Emulator block for the providers the doc lists under `## Emulators`.

**The Emulator block**, for each accepted provider, in the order of the doc's `## Emulators` bullets:

- In `scripts/dev-stack`, add one `EMULATORS` entry, `"<service> <path that answers 200 without credentials>"`, the path from the "emulate 0.13.0 notes" in `CONTRACT.md`, or for a service they don't name, one its README documents. In `emulator_env`, replace the commented examples with the provider's lines: the browser-facing URL from `emulator_url <service>`, and the webhook target and signing secret when it delivers webhooks. Under strategy B, the server-to-server URL comes from `b_emulator_api_url <service>`.
- **Strategy A**: keep `EMULATE_VERSION="0.13.0"`. The webhook target is the app's backend route, as in the template's commented line.
- **Strategy B**: draft `emulate.Dockerfile` at the repo root as `CONTRACT.md`'s "Emulators under strategy B" gives it, with `RUN npm install -g emulate@0.13.0`, and the `emulate` service in the dev Compose file from the same section. The service mounts the config the Config bullet drafts, `./emulate.config.yaml:/emulate/emulate.config.yaml:ro` or the same for `emulate.config.ts`; publishes one `127.0.0.1::<port>` per Emulator, counting up from `B_EMULATE_PORT` in `EMULATORS` order; and, for each Emulator that delivers webhooks, lists the webhook target and signing secret variables in its own `environment:`, since its config reads them inside the `emulate` container. The web service gets the app's Emulator variables. The webhook target is the web service's Compose address.
- **Config**: draft `emulate.config.yaml` at the repo root with throwaway users and the objects the app's seed refers to, and nothing else (a sign-in provider seeds `test@example.com`), no `oauth_clients` and no `baseUrl`. When an Emulator delivers webhooks, draft `emulate.config.ts` instead, reading the webhook target and secret from the variables `up` sets. Take the field names from emulate's README for 0.13.0.

With no accepted Emulator, every draft in this section is the one the steps above give without it: no `- Emulate:` line, no `## Emulators` section, the template's empty `EMULATORS=()` and commented `emulator_env` left as they are, and no emulate files.

Done when the doc is drafted, every accepted provider has its Emulator block drafted or listed in the issue, and either the script is drafted or the issue is drafted or declined.
