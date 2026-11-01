---
name: refresh-spec
description: "Check a spec and its tickets against the current code, propose updates for the stale ones, and apply them after you approve."
argument-hint: "A spec or ticket: issue number, URL, or local file path"
disable-model-invocation: true
---

# Refresh spec

A **Spec** and its **Tickets** describe the code as it stood when they were written. Commits land in the meantime: some work gets done, names and places change, ADRs and glossary terms appear. This skill finds every **Stale** Issue in one Spec, proposes the edits that bring it back in line with the code, and applies them once the user approves.

The issue tracker should have been provided to you. If not, tell the user to run `/setup-sdlc`.

## Process

### 1. Check the clone

The code you compare against has to be the code the Issues describe:

- The current repo is a clone of the repo whose tracker holds the Issues. For a local tracker this always holds. Otherwise, if the repos differ, stop and tell the user to run this skill from a clone of the Issues' repo.
- Fetch the remote's default branch. If `HEAD` does not contain its tip, stop and tell the user to update first. A repo with no remote skips this check.

Note `HEAD`'s short SHA: it is the **baseline** every comment in step 6 names.

### 2. Gather the Issues

The argument is a Spec or a single Ticket.

- **A Spec**: read it, then its Tickets: its native sub-issues, plus every Issue whose `## Parent` section points at it. On a local tracker, the Spec is the feature folder's spec file and the Tickets are the files in its `issues/` folder.
- **A single Ticket**: refresh only that Ticket, and read its Spec as context.

Read every Issue's full body and comments. A comment from an earlier refresh names its baseline; the commits since that baseline are where to look first.

Sort the Tickets:

- **Open**: the ones this skill refreshes.
- **In flight**: open, with an assignee or an open PR that references them. Compare them, but only report their findings: rewriting them moves the goalposts for whoever is working on them.
- **Closed**: context only, to learn what has shipped. Never edit them.

Read `GLOSSARY.md` and the ADRs too: the vocabulary and decisions the Issues should now respect.

### 3. Compare each Ticket with the code

Brief one sub-agent per open or in-flight Ticket, all in parallel. If your agent can't spawn sub-agents, run the same comparison yourself for each Ticket in turn.

Sub-agents only report: this session drafts and applies every change, so the edits stay consistent across Tickets. Each brief carries pointers, not copies: the Ticket, its Spec, the glossary and ADR paths, the baseline SHA. Ask the sub-agent to search the code relentlessly for every acceptance criterion and every name the Ticket mentions, and to return its findings in this shape, each with the evidence (file and line, or commit) that backs it:

- **Done**: acceptance criteria the code already meets.
- **Changed**: names, places or behaviour the Ticket cites that the code now has under another name or shape.
- **Vocabulary**: words the glossary now defines differently or avoids.
- **Contradiction**: places where the code made a different choice than the Ticket or Spec asks for, as opposed to running ahead of it.
- **Edges**: blocking edges that no longer hold, or new ones the code now implies.
- **Gap**: work the Spec needs that no Ticket covers.

The comparison is done when every acceptance criterion of every Ticket is marked done, not done, or contradicted, with evidence.

Then check each closed Ticket for its work in the code. One whose work is missing (reverted, regressed) becomes a finding for the report, never a reopen: whether it is a bug or an intended removal is a call for `triage`.

Last, read the Spec against the findings and the code, for the same kinds of staleness. The step is done when every closed Ticket and every user story in the Spec has been checked.

### 4. Draft the changes

Turn the findings into proposed changes. You may:

- rewrite a Ticket's body: drop or tick criteria already met, fix names and vocabulary;
- narrow a partly done Ticket to the work that is left, naming what already exists;
- close a Ticket whose every criterion is met, with a closing comment citing the evidence;
- redraw blocking edges;
- edit the Spec body.

Gaps become loose ends for `to-tickets`, never new Tickets: new scope is that skill's job, and splitting or merging Tickets is too.

A contradiction is reported, never resolved: you can't tell whether the Issue or the code is wrong, the same way Drift works for the Design direction. Put each one to the user as a question.

Rewritten bodies keep the template `to-tickets` and `to-spec` publish with, and their rule against file paths and code snippets: evidence goes in the comment from step 6, not in the body. Load the `prose-style` skill and write every body and comment in that style.

### 5. Show the proposal and approve

Write each draft body to the OS temporary directory, never into the repo, and show the user one proposal:

1. A unified diff per edited Issue (for example `git diff --no-index <current> <draft>`), each with the findings behind it.
2. The Tickets to close, with their evidence.
3. The blocking edges to add or remove.
4. The questions: each contradiction, with both sides.
5. Report only: findings on in-flight Tickets, closed Tickets whose work is missing, and gaps.

If nothing is stale, say the Issues match the code at the baseline and stop.

Change nothing on the tracker until the user explicitly approves the proposal ("yes", "apply"). They may drop items. An answered contradiction becomes an edit when the code wins, or a loose end for fixing the code when the Issue wins; either way show the revised proposal and ask again. Anything short of approval leaves every Issue as it was.

### 6. Apply

Apply the approved items through the tracker's conventions. The step is done when every approved item is applied and none of the dropped ones is.

- **Edited Issue**: replace its body, then comment `Refreshed at <baseline>: <what changed and why>`.
- **Closed Ticket**: close it with a comment naming the baseline and the evidence that its work exists. On a local tracker, closing means setting its `Status:` line to `done`.
- **Blocking edges**: add and remove them with the tracker's blocking-link convention.

## Finishing

List every Issue changed, with its link (or file path) and a line on what changed. Then list the loose ends: the questions the user deferred, code fixes the contradictions call for, in-flight findings for the assignee, closed Tickets for `triage`, and gaps for `to-tickets`. Name the next step: `implement <ticket>` for a frontier Ticket, or `implement-spec <spec>` to run them all.
