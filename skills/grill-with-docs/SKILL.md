---
name: grill-with-docs
description: A relentless interview to sharpen a plan or design, which also creates docs (ADR's and glossary) as we go.
disable-model-invocation: true
---

Load the `grilling` and `domain-modeling` skills. When the work has a UI, also load the `ui-design` skill and grill its design plan as part of the interview: the plan only, no code.

## Finishing

This skill is the first step of the feature flow: `grill-with-docs`, then `to-spec`, then `to-tickets`. Its only outputs are the decisions and the docs written during grilling. Specs, tickets, follow-up issues and edits to any other file belong to the later skills.

Shared understanding is reached when the user confirms it, or when the user invokes `to-spec`. Invoking the next skill counts as confirmation. At that point:

1. Commit the docs this session wrote (`GLOSSARY.md`, ADRs) on the feature branch, creating the branch if you are on the default branch.
2. Summarise the settled decisions, the design plan included. List every loose end (follow-up work, changes to other docs or rules) as input for the spec or for `implement`, not as actions to offer. When the design plan sets or changes the design direction, one loose end is running `update-design` once the UI ships.
3. Close by naming the next step: `to-spec`, or `implement` when the work fits one session.
