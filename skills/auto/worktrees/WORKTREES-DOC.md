# The worktrees doc

A repo's `docs/agents/worktrees.md` tells `worktree.sh create` how to make a new **Worktree** ready to run. `setup-sdlc` drafts it; the script reads the three headings below, each optional, and ignores the rest of the file.

~~~markdown
# Worktrees

## Copy

- `.env`
- `apps/web/.env.local`

## Install

```sh
npm ci
```

## Folder

`.claude/worktrees`
~~~

- **Copy** lists gitignored files or folders, one per bullet in backticks, as paths from the repo root. Each is copied from the main checkout when it exists there and the worktree lacks it.
- **Install** holds one fenced block, run with `sh` in the new worktree. A failure stops `create` with the worktree left in place; the next `create` for the branch runs the install again.
- **Folder** moves worktrees out of `.claude/worktrees`, as a path from the repo root. Leave it out unless the repo needs it: agents that switch sessions between worktrees may only do it under `.claude/worktrees/`.
