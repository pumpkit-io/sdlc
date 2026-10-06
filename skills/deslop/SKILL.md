---
name: deslop
description: "Clean up slop in comments, prose and UI under a file or folder, one concern at a time, editing the working tree."
argument-hint: "A file or folder, plus an optional request (for example \"only comments\")"
disable-model-invocation: true
---

# Deslop

Clean existing **Slop** out of a file or folder. You triage in your own context, then run one **wave** per concern (comments, prose, UI). Inside a wave, sub-agents each own a small batch of files and load exactly one skill; waves run one after another, so no two agents ever edit the same file at once. You edit the working tree directly and the user reviews the result with `git diff`.

The scope is what the three skills cover, accessibility fixes from `ui-craft` included. Code-level design (naming, structure, wrappers, error handling) is a smell for `code-review`: this skill names what it notices and leaves the code alone.

## Process

### 1. Scope

The argument is a path plus an optional request. With no path, ask for one.

List the target files under the path: in a git repo, `git ls-files` on the path plus untracked files that aren't ignored. Leave out vendored and generated files (`node_modules/`, `vendor/`, build output, lockfiles, minified bundles) and binaries.

`DESIGN.md` is never a target. Look for it at the repo root (`git rev-parse --show-toplevel`), not under the path. When it exists, you and every sub-agent read it as data; no one writes it, because the **Design direction** is frozen and only `update-design` changes it.

### 2. Uncommitted changes

Run `git status --porcelain` on the target files. When any of them has uncommitted changes, list them and warn the user that your edits would mix with theirs in `git diff`. Then ask: commit or stash first, leave those files out, or go ahead anyway. Edit nothing until they answer. Outside a git repo, say the result can't be reviewed with `git diff` and ask before going on.

### 3. Triage

Read each target file far enough to tag it with the concerns it carries:

- **comments**: a source file with comments (any language, including the `<script>` and `<style>` comments of a UI file).
- **prose**: text people read as a document (Markdown, plain-text docs, `README`s, ADRs, glossary entries, changelogs), plus the user-facing copy inside UI files: headlines, labels, empty states, error messages.
- **UI**: pages, components, templates and stylesheets. A UI file with user-facing copy is tagged for both prose and UI: the prose wave cleans its visible copy, and the UI wave handles the rest.

A file can carry several concerns. Weigh the tags against the user's request: "only comments" drops every other concern, "the landing page" narrows the UI concern to it. Drop a tag when the file has nothing for that concern to do (a source file with no comments).

Then cut each concern's files into **batches**: disjoint, at most five files each, with any file over about 500 lines in a batch of its own. Show the user the triage as a table (file, concerns) and the batch count per wave, then go on without waiting.

Done when every target file is tagged or named as skipped with a reason, and every tagged file sits in exactly one batch per concern.

### 4. Run the waves

Run the waves in this order, skipping any with no files: **comments**, then **prose**, then **UI**. Spawn one sub-agent per batch, all batches of a wave in parallel, and wait until every sub-agent in the wave has reported before starting the next wave.

If your agent can't spawn sub-agents, run the same waves in this session instead: one wave at a time in the same order, batch by batch, loading the wave's skill yourself and following the brief below as your own instructions. Finish a wave before starting the next.

Each sub-agent's brief carries:

- The one skill to load, by wave: comments load the `code-comments` skill, prose loads the `prose-style` skill, UI loads the `ui-craft` skill.
- Its batch: the exact files it may edit. Every other file is read-only, `DESIGN.md` included.
- The user's request, verbatim, or "none".
- The rules: "Apply the skill to every part of these files it covers, and edit them in place. Change only what the skill covers; logic, identifiers and code-level design stay as they are. Add no fact the files, the codebase or the request don't already hold. Never write `DESIGN.md`."
- For the prose wave, in a UI file: "Edit only the user-facing copy; markup, styles and code stay as they are."
- For the UI wave: "Load `ui-craft` and no other skill. The prose wave has already cleaned the user-facing copy, so skip the `ui-craft` entry that loads `prose-style` for UI copy."
- For the UI wave, also: "This is existing UI the user will review, so keep its structure: replace an invented number, name or claim in place with an honest placeholder (`[REAL DATA]`) rather than deleting the element, and leave removing sections to the user."
- For the UI wave: whether `DESIGN.md` exists at the repo root, with the instruction "Read it as data. Report every case of **Drift** you find in your files (file and line, what the code does, the `DESIGN.md` section and value it contradicts) and edit neither side: the drifted code stays as it is."
- The report: "Under 200 words: per file, what you changed, what you left and why, any code-level smell you noticed but left alone, then any Drift."

### 5. Check the result

Run `git diff --stat` and confirm two things: every changed file was in some batch, and `DESIGN.md` has no diff. Leave any file outside the batches as it is, since the change may be the user's own edit, and name it in the summary so they can check it. Treat a change to `DESIGN.md` the same way: report it and leave it.

### 6. Summarise

End with one section per wave that ran: the files it changed and the kinds of slop it removed, plus anything it left in place and why (a kept workaround comment, a placeholder that needs a real number) and any code-level smell it noticed, as a pointer to `code-review`. Write it to the `prose-style` skill.

Then a **Drift** section when any was found: each case as the sub-agent reported it, with the two ways out: fix the code to match `DESIGN.md`, or run `update-design` to adopt the code as the new direction. Neither side was edited.

Close by pointing the user to `git diff` to review.
