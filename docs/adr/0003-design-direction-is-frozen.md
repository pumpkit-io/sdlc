# The design direction is frozen

`DESIGN.md` records a repo's design direction, and only the user changes it, by invoking `update-design`. No skill edits it as a side effect: new UI follows it, and existing UI that contradicts it is reported as drift instead of being fixed on either side, because only the user knows whether the code or the direction is wrong.

## Considered Options

- **Keep `DESIGN.md` in sync automatically**, letting skills update it whenever the UI changes. Rejected: the file would quietly absorb whatever the agent last built, slop included, and stop being a direction at all.
- **Treat `DESIGN.md` as a hard dependency** of the UI skills, pointing to `/setup-sdlc` when it is missing. Rejected under ADR 0001: without it the output is less directed, not wrong.

## Consequences

`setup-sdlc` creates `DESIGN.md` (an empty skeleton, or extracted from the current UI by reading and following `update-design`'s instructions) and skips the step in repos with no UI. `ui-craft`, `deslop` and `code-review` read it and report drift; none of them write it.
