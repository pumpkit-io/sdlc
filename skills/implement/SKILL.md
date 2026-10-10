---
name: implement
description: "Implement a piece of work from a spec, tickets, or what this session settled."
disable-model-invocation: true
---

Implement the work from its source:

- **Spec or tickets**: the ones the user names.
- **The conversation**: when the user names no spec or ticket, the work is what this session settled, such as the decisions from `grill-with-docs` or a fix agreed while discussing a bug. Before writing code, post a short brief: the goal, each settled decision, which loose ends are in scope, and the seams you will test at (prefer existing seams, the highest one possible, as few as possible). Then carry on without waiting for a reply. If the session left the goal or a decision open, name what is open and ask instead.

Use /tdd where possible, at the seams the spec or brief agreed.

Load the `code-comments` skill before writing code; every comment you write follows it.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

Once done, use /code-review to review the work. When you worked from the conversation, hand it the brief as the spec.

Commit your work to the current branch.
