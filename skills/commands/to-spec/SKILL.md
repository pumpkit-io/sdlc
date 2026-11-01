---
name: to-spec
description: "Turn the current conversation into a spec and publish it to the project issue tracker: no interview, just synthesis of what you've already discussed."
disable-model-invocation: true
---

This skill takes the current conversation context and codebase understanding and produces a spec. Do NOT interview the user; just synthesize what you already know.

The issue tracker should have been provided to you. If not, tell the user to run `/setup-sdlc`.

Load the `worktrees` skill and resolve the worktree for this work before writing anything.

## Process

1. Explore the repo to understand the current state of the codebase, if you haven't already. Use the project's domain glossary vocabulary throughout the spec, and respect any ADRs in the area you're touching.

2. Sketch out the seams at which you're going to test the feature. Existing seams should be preferred to new ones. Use the highest seam possible. If new seams are needed, place them at the highest point you can. The fewer seams across the codebase, the better: the ideal number is one. Settle the seams yourself and record them under Testing Decisions.

3. When the feature has a UI, load the `ui-design` skill. Take the design plan settled in the conversation; when there is none, make one now, planning only, with its open choices recorded as open questions.

4. Load the `prose-style` skill. Write the spec in that style using the template below, then publish it to the project issue tracker. The body starts with the **Feature branch link**, `Branch: <branch>`, naming the branch this session's worktree is on (`git branch --show-current` there). Apply the `ready-for-agent` triage label - no need for additional triage.

<spec-template>

Branch: <feature branch>

## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A LONG, numbered list of user stories. Each user story should be in the format of:

1. As an <actor>, I want a <feature>, so that <benefit>

<user-story-example>
1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending
</user-story-example>

This list of user stories should be extremely extensive and cover all aspects of the feature.

## Implementation Decisions

A list of implementation decisions that were made. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include specific file paths or code snippets. They may end up being outdated very quickly.

Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it within the relevant decision and note briefly that it came from a prototype. Trim to the decision-rich parts, not a working demo, just the important bits.

## UI Design

Only when the feature has a UI. The design plan from step 3:

- Palette as named hex values, typefaces and their roles, and principles, each marked as taken from `DESIGN.md` or new to this feature
- The layout concept for each screen, with its ASCII wireframe
- Each screen's empty, loading and error states
- What the plan's review against the brief changed, and why

## Testing Decisions

A list of testing decisions that were made. Include:

- A description of what makes a good test (only test external behavior, not implementation details)
- The seams under test, from step 2
- Which modules will be tested
- Prior art for the tests (i.e. similar types of tests in the codebase)

## Out of Scope

A description of the things that are out of scope for this spec.

## Further Notes

Any further notes about the feature.

</spec-template>

## Finishing

Fold every loose end left in the conversation into the spec (Out of Scope or Further Notes), or into a spec of its own when it is separate work. A question the conversation left open goes under Further Notes as an open question. The spec issues are this skill's only output. Close by listing each published spec issue with its link, then naming the next step: `to-tickets`. Last, release this session's worktree lock, as the `worktrees` skill's Release section says.
