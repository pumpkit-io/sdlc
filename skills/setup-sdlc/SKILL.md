---
name: setup-sdlc
description: "Configure this repo for the engineering skills: set up its issue tracker, any triage label overrides, domain doc layout, worktrees, its CI review workflow on GitHub, in repos with a UI its DESIGN.md and, in repos with an app, Portless and a dev stack per worktree. Run once before first use of the other engineering skills."
disable-model-invocation: true
---

# Setup sdlc skills

Scaffold the per-repo configuration that the engineering skills assume:

- **Issue tracker**: where issues live (GitHub by default; local markdown is also supported out of the box)
- **Triage labels**: label strings for the five canonical triage roles, only when the repo doesn't use the role names themselves
- **Domain docs**: where `GLOSSARY.md` and ADRs live, and the consumer rules for reading them
- **Design direction**: a `DESIGN.md` at the repo root, only when the repo has a UI
- **Code comments**: a line in `AGENTS.md` so every session, in any flow, writes comments by the `code-comments` skill
- **CI review**: a GitHub Actions workflow that checks every pull request for comment slop and runs `review-changes` on it, only on GitHub
- **Worktrees**: the files and install command every new **Worktree** gets, the gitignore entries, and the `AGENTS.md` rule that keeps sessions out of the **Main checkout**
- **Portless and the dev stack**: only when the repo has a runnable app, Portless and its proxy on this machine, the dev stack doc, and either a drafted `scripts/dev-stack` or one issue to make the app worktree-safe

This is a prompt-driven skill, not a deterministic script. Explore, present what you found, confirm with the user, then write on a `chore/setup-sdlc` worktree and finish with the `check-sdlc` checklist.

## Process

### 1. Explore

Look at the current repo to understand its starting state. Read whatever exists; don't assume:

- `git remote -v` and `.git/config`: is this a GitHub repo? Which one?
- `AGENTS.md` and `CLAUDE.md` at the repo root: does either exist? Is either a symlink to the other? Does `CLAUDE.md` already contain an `@AGENTS.md` line? Which of them holds an `## Agent skills` section, if any?
- `GLOSSARY.md` and `GLOSSARY-MAP.md` at the repo root
- `docs/adr/` and any `src/*/docs/adr/` directories
- `docs/agents/`: does this skill's prior output already exist?
- `.scratch/`: a sign that a local-markdown issue tracker convention is already in use
- Is the `triage` skill installed? (a `triage` skill folder alongside this one, or `triage` in your available skills.) This decides whether Section B runs at all.
- Does the repo have a UI? Signals: HTML, CSS or component files (`.tsx`, `.jsx`, `.vue`, `.svelte`), a frontend framework in `package.json`, mobile UI code (SwiftUI, Android layouts, Flutter widgets), templates rendered by a web server. A library, CLI or backend service has none. Is there already a `DESIGN.md` at the root? Together these decide Section D.
- `.github/workflows/sdlc-review.yml`: is the CI review already installed?
- Monorepo signals: a `pnpm-workspace.yaml`, a `workspaces` field in `package.json`, or a populated `packages/*` with its own `src/`. These are present only in a genuinely large multi-package repo; their absence means single-context, which is almost every repo.
- `docs/agents/worktrees.md` and `.gitignore`: does `git check-ignore` already cover `.claude/worktrees/` and `.sdlc/`?
- Bootstrap files: the gitignored files a fresh checkout lacks and the app or tests need (`.env`, `.env.local`; `git status --ignored --short` in the main checkout lists them), and the install command the lockfiles imply (`npm ci`, `pnpm install --frozen-lockfile`, `uv sync`, `bundle install`).
- Repo-root tools that would scan `.claude/worktrees/`: test runners, linters, formatters, type checkers, watchers and content globs run from the root. For each, whether it already skips gitignored paths or needs the folder in its own ignore list, and which config file holds that list.
- Does the repo have a runnable app? Signals: a `dev` or `start` script in `package.json`, a Compose file whose services publish ports, `manage.py`, `bin/rails`, a `Procfile`, a server the README says to start. A library, CLI or docs-only repo has none. This decides Sections G and H. With an app, also find:
  - Each **isolation blocker**, with its file: fixed host ports (`"5173:5173"` in a Compose file, a pinned `--port`), a fixed Compose name (a top-level `name:`, `container_name:`), hard-coded app URLs (`localhost:<port>` in config or env defaults), e2e URLs pinned to a port (a Playwright `baseURL`, a health-check script), a shared database (one fixed database name or URL), and workers with outside effects (publishing, mail, payments, third-party webhooks) on by default.
  - How it runs in development (Docker Compose or native dev servers), its health endpoint, its e2e suite and command, and the variable it reads its own public URL from.
  - `docs/agents/dev-stack.md` and `scripts/dev-stack`, if a previous setup wrote them.
  - The machine: `node --version` (Portless 0.15.12 needs Node 24 or later); `portless --version`; the proxy, from `proxy.port` and `proxy.tls` (`1` for HTTPS) in `$PORTLESS_STATE_DIR` (default `~/.portless`) and whether `curl -sk` gets any answer on that port; passwordless sudo, from whether `sudo -n true` succeeds; Docker, from `docker info`. Read the proxy's options from `portless --help`, never `portless proxy start --help`, which starts a proxy in 0.15.12.

### 2. Present findings and ask

Summarise what's present and what's missing. Then take the sections in order. One section, one answer, then the next.

Lead each section with the recommended answer so the user can accept it in a word. Give a one-line explainer only when the choice genuinely branches; skip the section entirely when exploration already settled it (Section B when `triage` isn't installed, Section C when there's no monorepo, Section D when the repo has no UI, Section E when the tracker isn't GitHub). With no runnable app, skip Sections G and H without a question or a mention.

**Section A: Issue tracker.**

> Explainer: The "issue tracker" is where issues live for this repo. Skills like `to-tickets`, `triage`, and `to-spec` read from and write to it. They need to know whether to call `gh issue create`, write a markdown file under `.scratch/`, or follow some other workflow you describe. Pick the place you actually track work for this repo.

Default posture: these skills were designed for GitHub. If a `git remote` points at GitHub, propose that. If a `git remote` points at GitLab (`gitlab.com` or a self-hosted host), propose GitLab. Otherwise (or if the user prefers), offer:

- **GitHub**: issues live in the repo's GitHub Issues (uses the `gh` CLI)
- **GitLab**: issues live in the repo's GitLab Issues (uses the [`glab`](https://gitlab.com/gitlab-org/cli) CLI)
- **Local markdown**: issues live as files under `.scratch/<feature>/` in this repo (good for solo projects or repos without a remote)
- **Other** (Jira, Linear, etc.): ask the user to describe the workflow in one paragraph; the skill will record it as freeform prose

Record the choice in `docs/agents/issue-tracker.md`. The GitHub and GitLab templates carry a "PRs as a request surface" flag, defaulted **off**. Leave it off and don't raise it: a user who wants external PRs in the triage queue can flip the flag in the file later.

**Section B: Triage label vocabulary.** Skip this section entirely if the `triage` skill isn't installed (exploration told you), since an uninstalled skill needs no labels.

If it is installed, ask exactly one question:

> Do you want to keep the default triage labels? (recommended: **yes**)

The defaults are the five canonical roles, each label string equal to its name: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. On **yes**, write nothing: skills use the role names as label strings when no mapping file exists. Only if the user says no, usually because their tracker already uses other names (e.g. `bug:triage` for `needs-triage`), collect the overrides so `triage` applies existing labels instead of creating duplicates. If an existing `docs/agents/triage-labels.md` maps every role to its own name, propose deleting it (and its `### Triage labels` sub-block): it carries no information.

**Section C: Domain docs.** Default to **single-context** (one `GLOSSARY.md` + `docs/adr/` at the repo root). This fits almost every repo; write it without asking.

Offer **multi-context** (a root `GLOSSARY-MAP.md` pointing to per-context `GLOSSARY.md` files) only when exploration found monorepo signals. Then confirm which layout they want.

**Section D: Design direction.** Skip this section entirely if the repo has no UI (exploration told you): there is nothing for a direction to steer. If a `DESIGN.md` already exists, leave it as it is and mention that `update-design` changes it.

Otherwise ask one question:

> Create a `DESIGN.md` for the UI's design direction? (recommended: **extract it from the current UI**)

- **Extract**: resolve the `chore/setup-sdlc` worktree first, as step 4 describes, so `update-design` finds itself in it and commits there. Then read `update-design/SKILL.md` from the skill folder alongside this one and follow it now, skipping its release step. It reads the UI, shows its draft as a diff and writes `DESIGN.md` only once the user approves, so extraction finishes inside this section.
- **Empty skeleton**: take [design.md](./design.md) unchanged as the draft of `DESIGN.md` at the repo root, for the user to fill in later (direction, palette, type, spacing, motion, voice). Write nothing yet: the draft goes to step 3 with the other drafts and is written in step 4.
- **None**: write nothing.

**Section E: CI review.** Skip this section when the repo isn't on GitHub. If `.github/workflows/sdlc-review.yml` already exists, offer to replace it with the current template and show the diff first.

Otherwise ask one question:

> Add a CI workflow that reviews every pull request? (recommended: **yes**)

On **yes**, take [sdlc-review.yml](./sdlc-review.yml) unchanged as the draft of `.github/workflows/sdlc-review.yml`; it goes to step 3 with the other drafts. Explain its two jobs in one line each: `comment-slop` fails when a pull request adds comment slop a pattern can catch, and `review` runs `review-changes` with Claude Code, posts the report as one pull request comment updated on every push, and fails when the report's verdict is blocking. To block merges on them, the user marks both jobs as required checks in the repo's branch protection; that change is theirs to make. The `review` job needs a `CLAUDE_CODE_OAUTH_TOKEN` secret: the user creates the token with `claude setup-token`, then adds it with `gh secret set CLAUDE_CODE_OAUTH_TOKEN`. Never ask for the token or handle it yourself. On a public repo, say that the `review` job skips pull requests from forks, so outsiders can't spend the user's usage.

**Section F: Worktrees.** Runs in every repo, app or not. Draft `docs/agents/worktrees.md` in the format of `worktrees/WORKTREES-DOC.md` (in the skill folder alongside this one): the bootstrap files under Copy, the install command under Install, and no Folder heading. With nothing to copy or install, the draft is the `# Worktrees` heading and the line "New worktrees need no copied files and no install." When the doc already exists, keep it and propose only the bullets Explore found missing. Ask one question:

> Copy <files> into each new worktree and run `<install command>` there? (recommended: **yes**)

Add to the drafts: the `.gitignore` lines `.claude/worktrees/` and `.sdlc/` that `git check-ignore` showed missing, and, for each repo-root tool that would scan `.claude/worktrees/`, the ignore entry in its own config file.

**Sections G and H: Portless and the dev stack.** Only with a runnable app: read [PORTLESS-DEV-STACK.md](PORTLESS-DEV-STACK.md) and follow it. Section G sets up this machine as it goes; Section H adds drafts for step 3.

### 3. Confirm and edit

Show the user a draft of:

- The `## Agent skills` block to write to `AGENTS.md`, plus any `CLAUDE.md` edit step 4 calls for (adding `@AGENTS.md`, or removing an old block)
- The contents of `docs/agents/issue-tracker.md`, `docs/agents/domain.md`, and `docs/agents/triage-labels.md` (the last only when the user gave label overrides in Section B)
- `DESIGN.md`, only when the user chose the empty skeleton in Section D
- `.github/workflows/sdlc-review.yml`, only when the user said yes in Section E
- `docs/agents/worktrees.md`, the `.gitignore` lines and the tool ignore entries from Section F
- `docs/agents/dev-stack.md`, and either `scripts/dev-stack` or the body of the "Make the dev stack worktree-safe" issue, from Section H

Let them edit before writing.

### 4. Write

**Where the writes land.** Load the `worktrees` skill and resolve a worktree for the branch `chore/setup-sdlc` (Section D's extract may already have). Every file below is written in that worktree, never in the main checkout.

**Where the block goes:**

`AGENTS.md` is the shared file: Codex, Cursor and OpenCode read it directly, Claude Code reads it through `CLAUDE.md`, and Gemini CLI reads it once `GEMINI.md` points at it. Always write the block to `AGENTS.md`:

- If either file is a symlink to the other, they are one file: update or add the block in it and skip the `CLAUDE.md` rules below.
- Create `AGENTS.md` if it doesn't exist.
- If an `## Agent skills` block already exists in it, update its contents in place rather than appending a duplicate. Don't overwrite user edits to the surrounding sections.

Then, only if `CLAUDE.md` exists:

- If it doesn't already contain an `@AGENTS.md` line, add `@AGENTS.md` as its first line.
- If it holds an `## Agent skills` block from an earlier setup, remove that block: its content now lives in `AGENTS.md`.

If `CLAUDE.md` doesn't exist, don't create it. Never edit `GEMINI.md`.

The block:

```markdown
## Agent skills

### Issue tracker

[one-line summary of where issues are tracked]. See `docs/agents/issue-tracker.md`.

### Triage labels

[one-line summary of the label overrides]. See `docs/agents/triage-labels.md`.

### Domain docs

[one-line summary of layout: "single-context" or "multi-context"]. See `docs/agents/domain.md`.

### Code comments

Load the `code-comments` skill before writing or editing any comment.

### Worktrees

Never edit files or commit in the main checkout, even for a one-line change. Before your first file change or commit, load the `worktrees` skill and resolve a worktree for the work, then work and commit there. Release its lock when the work is committed. The one exception is a main-checkout path a skill names, such as `improve-codebase-architecture`'s notes.

### Dev stack

Start, check and stop the app only through `scripts/dev-stack`: load the `dev-stack` skill when you need it running. See `docs/agents/dev-stack.md`.
```

Include the `### Triage labels` sub-block, and write `docs/agents/triage-labels.md`, only when the user gave label overrides in Section B. With the default labels, both are omitted. Include the `### Dev stack` sub-block only when Section H wrote `docs/agents/dev-stack.md`.

Then write the docs files using the seed templates in this skill folder as a starting point:

- [issue-tracker-github.md](./issue-tracker-github.md): GitHub issue tracker
- [issue-tracker-gitlab.md](./issue-tracker-gitlab.md): GitLab issue tracker
- [issue-tracker-local.md](./issue-tracker-local.md): local-markdown issue tracker
- [triage-labels.md](./triage-labels.md): label overrides (only if the user gave any)
- [domain.md](./domain.md): domain doc consumer rules + layout
- [design.md](./design.md): the `DESIGN.md` skeleton (only if the user chose it in Section D)
- [sdlc-review.yml](./sdlc-review.yml): the CI review workflow, written to `.github/workflows/sdlc-review.yml` (only if the user said yes in Section E)

For "other" issue trackers, write `docs/agents/issue-tracker.md` from scratch using the user's description.

Write the Section F and H files as approved in step 3. Make `scripts/dev-stack` executable before committing it.

**Commit and file.** Commit everything on `chore/setup-sdlc` as one commit, `chore: set up the sdlc skills`. Then, when the user said yes to it in Section H, file the "Make the dev stack worktree-safe" issue on the tracker, as `docs/agents/issue-tracker.md` describes.

Done when `git status` in the worktree is clean and the issue, if any, has its number.

### 5. Check

Read `check-sdlc/SKILL.md` from the skill folder alongside this one and follow it, with two changes while `chore/setup-sdlc` is unmerged: run `check.sh <worktree path>` every round, so the repo checks read the new files, and land repo-file fixes on `chore/setup-sdlc` instead of `chore/sdlc-fixes`. Skip its step 6; step 6 below hands the branch over.

In the blocker case, `devstack.script` fails until the issue lands; name the issue next to it.

Done when the checklist's loop has ended.

### 6. Hand over

Offer a pull request for `chore/setup-sdlc` (load the `pr` skill for its body). Fast-forward the default branch instead only when the user says yes to that explicitly: with the main checkout on `<default>` and clean, run `git -C <main> merge --ff-only chore/setup-sdlc`, then offer to push `<default>`. That fast-forward is the one write to the main checkout this skill makes.

Say plainly: new worktrees branch from `origin/<default>`, so they don't have the `### Worktrees` rule, the worktrees doc or the dev stack doc until `chore/setup-sdlc` reaches the default branch there.

Release the worktree's lock. After a fast-forward, finish the worktree with `worktree.sh finish <path> --merged-into <default>`.

### 7. Done

Tell the user the setup is complete and which engineering skills will now read from these files. If a `DESIGN.md` now exists, add that it changes only through `update-design`. If the CI review was installed, remind the user to add the `CLAUDE_CODE_OAUTH_TOKEN` secret before the next pull request. Mention they can edit `docs/agents/*.md` directly later. Re-running this skill is for switching issue trackers or starting over; for anything else that looks wrong later, they run `check-sdlc`.

Say which file got the block and whether `CLAUDE.md` is linked to it (by import or symlink). If there is no `CLAUDE.md`, add one line for Claude Code users: create a `CLAUDE.md` containing `@AGENTS.md`.

End with the checks that still fail, each with the exact command only the user can run (the HTTPS upgrade, the review secret, a `sudo` install), or with the one line `check-sdlc` printed when everything passed.
