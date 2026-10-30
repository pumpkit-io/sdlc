# Portless on plain HTTP, port 1355, by default; HTTPS on 443 as the one-sudo upgrade

`setup-sdlc` installs Portless and starts its proxy itself, so the user does no manual machine setup. Agents run without a TTY and cannot answer a `sudo` prompt, and every port-free option needs root. Portless 0.15.12 binds 443 for HTTPS or 80 with `--no-tls`, and on macOS binding `127.0.0.1:80` as a normal user fails with `EACCES`. So the default is the one mode that needs no root anywhere:

- **Default**: `portless proxy start -p 1355 --no-tls`. **Dev URLs** look like `http://login.pumpkit.localhost:1355`. The port is the proxy's, shared by every stack on the machine, so a URL still never changes for a branch. When asked for port 80 without a TTY, Portless itself falls back to 1355.
- **Upgrade, offered once**: HTTPS with HTTP/2 on 443, through `portless trust` and `portless service install`, as one command the user pastes with `sudo` (or the agent runs, when `sudo -n true` succeeds). It gives port-free URLs, and HTTP/2 removes the six-connection limit that slows Vite's first page load. The service install is part of it because a proxy started with `sudo` doesn't survive a reboot, and a contract's `up` cannot restart it without a password.

The proxy always runs with `PORTLESS_SYNC_HOSTS=0`, because its `/etc/hosts` sync needs root on every route change. Chrome, Firefox, Edge, `curl` and Node's `fetch` resolve `*.localhost` without it (checked on macOS). Safari may not; the user can run `portless hosts sync` once.

Portless is pre-1.0, so the version is pinned (0.15.12 when this was decided) and recorded with the mode in `docs/agents/dev-stack.md`; `check-sdlc` warns when the installed version differs.

## Considered Options

- **HTTP on port 80.** Rejected: needs the same `sudo` as HTTPS on 443 and gives neither HTTP/2 nor `https://`.
- **HTTPS on 443 as the default.** Rejected: setup could not finish unattended on any OS.
