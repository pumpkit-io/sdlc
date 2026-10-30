# One worktree per unit of work, chosen by the skills; agents never write in the main checkout

Every session that is about to change a file or commit first resolves a **Worktree** and moves into it. The user's routine does not change: they open the agent in the **Main checkout**, type the usual skills, and may run tens of sessions at once. Without this, sessions grilling in one checkout overwrite each other's uncommitted `GLOSSARY.md` and ADR edits, and the user's own checkout fills with agent changes.

Three layers make it the default. An `AGENTS.md` rule, written by `setup-sdlc`, tells every agent never to edit or commit in the main checkout and to load the `worktrees` skill before its first file change. Every writing skill resolves its worktree as its first step. In Claude Code, a plugin hook blocks file writes and commits in the main checkout; `SDLC_ALLOW_MAIN_CHECKOUT=1` turns it off for one session.

The rules that hang off this:

- Worktrees live in `<main checkout>/.claude/worktrees/<slug>/`, gitignored, never nested in another worktree. Agents sandbox file access to the project directory, and this is where Claude Code's own worktree tools put worktrees, so a session can switch between any of them.
- Skills find the worktree themselves: stay in a fitting worktree; for a **Spec** or **Ticket**, follow its **Feature branch link**; otherwise create a new branch off `origin/<default>`. When the work names an existing branch, the skill adds a worktree for it, and stops if that branch is checked out in the main checkout rather than switching the user's checkout.
- A **Slug** is the branch's last segment, lowercased, with every character outside `[a-z0-9-]` turned into `-`. That is how Portless prefixes worktree URLs (checked on 0.15.12: `feat/Login_Flow.v2` became `login-flow-v2`), so slugs are unique per repo. `implement-spec` names implementer branches `<feature-slug>-t<ticket>` and merge branches `<feature-slug>-m<ticket>`, so the feature survives into the slug.
- A **Worktree lock** allows one session per worktree. A lock is stale after two hours with no file change and no commit. A busy feature worktree stops `implement` with the holder named; running a Spec's Tickets in parallel is `implement-spec`'s job.
- Removing a worktree never discards work: it needs a clean tree and a merged branch (or one the user says an open PR covers). `git worktree remove --force` and `git branch -D` stay blocked.
- ADR numbers are allocated across `origin/<default>` and every local branch, so parallel grilling sessions don't pick the same number.

## Considered Options

- **Worktrees in a sibling directory** (`../repo.worktrees/`). Rejected: agents reset the shell directory and ask permission for edits outside the project, so a session can't move there mid-task.
- **A harness-only `.worktrees/` folder.** More neutral for other agents, but Claude Code can only switch a session from one worktree into another when both are under `.claude/worktrees/`.
- **The user starts each session in a worktree** (`claude -w`). Rejected: it is a habit, not a default, and forgetting it once writes to the main checkout. It still works: the skills find themselves in a worktree and stay.
- **A ticket worktree off a busy feature branch**, merged back by the user. Rejected: it leaves the user a merge that `implement-spec` already does.
- **Warn instead of blocking in the main checkout.** Rejected: blocking is what makes the rule hold in sessions where no skill ran.
