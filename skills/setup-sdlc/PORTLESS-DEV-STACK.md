# Sections G and H: Portless and the dev stack

Only for a repo with a runnable app. Section G sets up Portless on this machine and runs as it goes, from the main checkout, because nothing it changes lives in the repo. Section H drafts the repo's **Dev stack** files for step 3. The contract both serve is `dev-stack/CONTRACT.md`, in the skill folder alongside this one: read it before Section H.

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

2. **The dev stack doc.** Draft `docs/agents/dev-stack.md` in the format under "The dev stack doc" in `CONTRACT.md`: entry point `scripts/dev-stack`; the strategy; the project, from the repo's name in lowercase `[a-z0-9-]`; the health URL path (`/` when the app has no health endpoint); the e2e command, when there is a suite; cap 4; Portless 0.15.12 and the mode from Section G; one Safe mode bullet for each worker with an outside effect, naming the variable `up` sets and what it turns off; the HTTPS upgrade command, only in HTTPS mode; and the browser notes as the format gives them. When the doc exists, keep it and propose only the lines the format lacks.
3. **Contract or issue.** Which one depends on Explore's isolation blockers.
   - **No blockers**: draft `scripts/dev-stack` from `dev-stack/scripts/dev-stack.template.sh`. Keep the chosen strategy's block and delete the other; set `PROJECT`, `STRATEGY`, `PROXY_PORT`, `PROXY_TLS` (1 for HTTPS), `HEALTH_PATH` and `APP_URL_VAR` to the doc's values; fill every TODO from the repo (the dev server command, migrations and seed, the Compose file, web service and port, the safe-mode exports) and delete each TODO line once it is filled. It goes to step 3 for approval.
   - **Blockers**: draft no script and change no app code. Ask one question:

     > Open one issue, "Make the dev stack worktree-safe", listing each blocker? (recommended: **yes**)

     On **yes**, draft its body for step 3: each blocker with its file and the change the contract needs, the chosen strategy, and that `implement` then drafts `scripts/dev-stack` from the `dev-stack` skill's template and `CONTRACT.md`. It is filed in step 4.

Done when the doc is drafted and either the script is drafted or the issue is drafted or declined.
