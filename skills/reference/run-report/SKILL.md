---
name: run-report
description: The structure of the Run report, the message an implementing skill ends its run with. Use when a skill says to write the Run report.
user-invocable: false
---

The **Run report** is the run's last message to the user. The user scans it to see whether anything needs them and where to click, so every report has the same shape, and the PR body carries the detail. Load the `prose-style` skill and write it in that style.

```markdown
**<status>**: <one clause saying why>

### Links
- Stack, merge order:
  1. <full PR URL> (<Ticket>)
  2. <full PR URL> (<Ticket>)
- Branch: <branch>
- Worktree: <absolute path>

### Done
- <one line per change>

### Checks
- <check>: <pass, fail, or skipped because …>

### Open
- <item>

### Before merging
- <item>

### After merging
- <item>
```

Every section appears in every report, in this order, and an empty one reads `- None.` That line is a claim: write it only when you checked and found nothing. Use bullets, never tables, and keep the whole report to about 30 lines, blank lines aside.

## Status

Exactly one of:

- **Ready to merge**: the run finished clean and every pull request of the **Stack** is open for review.
- **Stack stopped at Group <n>**: a **Group** could not finish clean, so the later Groups were not started. The pull requests already open stay, and the reason names the failing Ticket and the check that failed.
- **Clean, no PR**: every check passed, but the `pr` skill opened no PR (no supported code host, or the push was refused). Open says why.
- **Blocked, nothing pushed**: the run didn't finish clean, and Open says why.

## Sections

- **Links**: one `Label: value` bullet each, except the Stack, which lists one pull request per line in merge order (first to merge first), with URLs and absolute paths written out in full, so the terminal makes them clickable. Add `Issues: <issues>` for the Spec and Tickets the work came from, named as the `pr` skill names them, and the `dev-stack` skill's `Dev URL:` line when a **Dev stack** is left running. A run with no PR has no Stack lines.
- **Done**: what changed in the system's behaviour, at most five one-line bullets. Name a function or file only when it is the subject of the change. Tag anything outside what the source asked for `(beyond the ask)`, and a bug the review caught and you fixed `(fixed in review)`.
- **Checks**: one bullet for each of typechecking, the full test suite, the last `review-changes` verdict, the dev stack or e2e check, and the tests added. A skipped check says why in a clause. When the `dev-stack` skill ran, its `Checked there:` line is the dev stack bullet.
- **Open**: what is wrong or unfinished. Blockers come first, then review findings left unfixed, bugs found outside the work's scope, and any worktree left behind that blocks something, each with where it lives.
- **Before merging**: starts with "Merge the pull requests first to last; the agent merged none." Then what the user should do or check before merging: a manual check the run couldn't make, a judgement-call finding to read, a migration or config to apply. Each one says what to do, and what happens if they skip it. A check that relied on an **Emulator** adds one item per provider, as the `dev-stack` skill's Report step hands it over, for example: "Sign in with real Google before release: the check ran against the Google Emulator, so a callback that only real Google rejects would first fail in production."
- **After merging**: what follows the merge: the `worktrees` skill's Sweep, `update-design` when the UI set or changed the **Design direction**, follow-up work the run surfaced, and any worktree left behind that blocks nothing.

Leave out what needs nothing from the user: lock releases, the review rounds told as a story, steps that went as the skill says.
