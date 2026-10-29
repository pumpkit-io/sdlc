---
name: review-changes
description: "Review the changes since a fixed point (commit, branch, tag, or merge-base) along three axes: Standards (does the code follow this repo's documented coding standards?), Spec (does the code match what the originating issue/spec asked for?) and Correctness (does it introduce bugs?). Runs the three reviews in parallel sub-agents, reports them side by side, and ends with a pass or blocking verdict. Use when the user wants to review a branch, a PR, work-in-progress changes, or asks to \"review since X\"."
---

Three-axis review of the diff between `HEAD` and a fixed point the user supplies:

- **Standards**: does the code conform to this repo's documented coding standards?
- **Spec**: does the code faithfully implement the originating issue / spec?
- **Correctness**: does the code do what it means to, without bugs?

The three axes run as **parallel sub-agents** (or one after another when your agent can't spawn them; see step 4) so they don't pollute each other's context, then this skill aggregates their findings and gives a **verdict**: pass, or blocking.

The issue tracker should have been provided to you. If `docs/agents/issue-tracker.md` is missing, tell the user to run `/setup-sdlc`.

When nobody can answer (a CI job), never ask: take the fixed point and the spec source from the caller, skip the Spec axis when no spec turns up, and say in the report what you assumed.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point (a commit SHA, branch name, tag, `main`, `HEAD~5`, etc.). If they didn't specify one, ask for it.

Capture the diff command once: `git diff <fixed-point>...HEAD` (three-dot, so the comparison is against the merge-base). Also note the list of commits via `git log <fixed-point>..HEAD --oneline`.

Before going further, confirm the fixed point resolves (`git rev-parse <fixed-point>`) and the diff is non-empty. A bad ref or empty diff should fail here, not inside three parallel sub-agents.

### 2. Identify the spec source

Look for the originating spec, in this order:

1. Issue references in the commit messages (`#123`, `Closes #45`, GitLab `!67`, etc.), fetched via the workflow in `docs/agents/issue-tracker.md`.
2. A path the user passed as an argument.
3. A spec file under `docs/`, `specs/`, or `.scratch/` matching the branch name or feature.
4. If nothing is found, ask the user where the spec is. If they say there isn't one, the **Spec** sub-agent will skip and report "no spec available".

### 3. Identify the standards sources

Anything in the repo that documents how code should be written, such as `CODING_STANDARDS.md` or `CONTRIBUTING.md`.

On top of whatever the repo documents, the Standards axis always carries the **smell baseline** below: a fixed set of Fowler code smells (_Refactoring_, ch.3) that applies even when a repo documents nothing. Two rules bind it:

- **The repo overrides.** A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a judgement call.** Each smell is a labelled heuristic ("possible Feature Envy"), never a hard violation. Like any standard here, skip anything tooling already enforces.

Each smell reads *what it is* → *how to fix*; match it against the diff:

- **Mysterious Name**: a function, variable, or type whose name doesn't reveal what it does or holds. → rename it; if no honest name comes, the design's murky.
- **Duplicated Code**: the same logic shape appears in more than one hunk or file in the change. → extract the shared shape, call it from both.
- **Feature Envy**: a method that reaches into another object's data more than its own. → move the method onto the data it envies.
- **Data Clumps**: the same few fields or params keep travelling together (a type wanting to be born). → bundle them into one type, pass that.
- **Primitive Obsession**: a primitive or string standing in for a domain concept that deserves its own type. → give the concept its own small type.
- **Repeated Switches**: the same `switch`/`if`-cascade on the same type recurs across the change. → replace with polymorphism, or one map both sites share.
- **Shotgun Surgery**: one logical change forces scattered edits across many files in the diff. → gather what changes together into one module.
- **Divergent Change**: one file or module is edited for several unrelated reasons. → split so each module changes for one reason.
- **Speculative Generality**: abstraction, parameters, or hooks added for needs the spec doesn't have. → delete it; inline back until a real need shows.
- **Message Chains**: long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method on the first object.
- **Middle Man**: a class or function that mostly just delegates onward. → cut it, call the real target direct.
- **Refused Bequest**: a subclass or implementer that ignores or overrides most of what it inherits. → drop the inheritance, use composition.

Next to the smells, the Standards axis carries the **code tells**: patterns generated code leaves behind. Same two rules, same format:

- **Defensive code for impossible cases**: a try/except, null check or fallback for a value the types, the caller or the framework already guarantee; a catch that only logs and rethrows; a broad catch that swallows the error. → delete it, or narrow it to the failure that can happen.
- **Dead code**: unused parameters, imports, variables and branches; commented-out code. → delete it.
- **Reinvented helpers**: code that redoes what the standard library, a dependency or an existing function in the repo already does. → call the existing one.
- **Leftover debug output**: `print`, `console.log` or temporary logging, and log lines that only restate the code. → remove it, or make it a real log line with the context someone needs.
- **Verbose control flow**: nested conditionals, flags and manual loops where an early return, one expression or a built-in does the same. → flatten it.
- **Redundant conversions**: casts, copies and conversions applied to a value that already has that type or shape. → drop them.

**Tests** added or edited → load the `tdd` skill and check them against its "What a good test is" and "Anti-patterns" sections. A test at a seam the spec doesn't record is a finding too.

Next to the smell baseline, the Standards axis carries a **slop baseline**: **Slop** in the comments, prose and UI the diff adds or changes. Its rules live in three skills; the Standards pass loads each one the diff reaches, and skips the rest:

- **Comments** added or edited in any file → load the `code-comments` skill.
- **Prose** added or edited: docs, `README`s, ADRs, glossary entries, specs, user-facing strings → load the `prose-style` skill.
- **UI** added or edited: pages, components, styles, UI copy → load the `ui-design` skill and review against its "Reviewing and cleaning UI" section.

The same two rules bind it:

- **The repo overrides.** A documented repo standard always wins; where it endorses something the slop baseline would flag, suppress the slop finding.
- **Always a judgement call.** Each slop finding is a labelled heuristic ("possible restating comment"), never a hard violation, and is reported only for lines the diff touches.

When the diff touches UI and `DESIGN.md` exists at the repo root, the Standards pass also reports **Drift**: changed UI that contradicts `DESIGN.md`. Each case names the file and hunk, what the code does, and the `DESIGN.md` section and value it contradicts, then points to the two ways out: fix the code, or run `update-design` to adopt it. Drift is reported, never resolved: the review edits neither side.

### 4. Spawn the three sub-agents in parallel

If your agent can't spawn sub-agents, run the three reviews one after another in this session instead: Standards, then Spec, then Correctness, each written up in full before the next one starts, and don't let one pass's findings shape the next. The prompts below become your own brief for each pass; for the Standards pass, load the slop-baseline skills the diff reaches in this session yourself.

**Standards sub-agent prompt** should include:

- The full diff command and commit list.
- The list of standards-source files you found in step 3, **plus the smell baseline, the code tells and the slop baseline from step 3** pasted in full (the sub-agent has no other access to them).
- Which slop-baseline skills the diff reaches (comments, prose, UI), with the instruction to load each one before reviewing; whether the diff touches tests, with the instruction to load `tdd`; and whether `DESIGN.md` exists at the repo root.
- The brief: "Report, per file/hunk where relevant, (a) every place the diff violates a documented standard: cite the standard (file + the rule); (b) any baseline smell or code tell you spot: name it and quote the hunk; (c) any test that breaks the `tdd` skill: name the anti-pattern and quote the test; (d) any slop in the comments, prose or UI the diff touches: name the pattern and the skill it comes from, and quote the line; and (e) any Drift between changed UI and `DESIGN.md`, naming the section and pointing to `update-design`, editing nothing. Mark each finding **hard** or **judgement call**: only a documented-standard breach can be hard; smells, code tells, test findings and slop are always judgement calls, and a documented repo standard overrides all of them. Skip anything tooling enforces. Under 500 words."

**Spec sub-agent prompt** should include:

- The diff command and commit list.
- The path or fetched contents of the spec.
- The brief: "Report: (a) requirements the spec asked for that are missing or partial; (b) behaviour in the diff that wasn't asked for (scope creep); (c) requirements that look implemented but where the implementation looks wrong. Quote the spec line for each finding. Mark (a) and (c) **hard** and (b) **judgement call**. Under 400 words."

If the spec is missing, skip the Spec sub-agent and note this in the final report.

**Correctness sub-agent prompt** should include:

- The diff command and commit list. Not the spec: this axis judges the code on its own terms, so it runs whether or not a spec exists.
- The brief: "Read the diff and the code around it, then report the bugs it introduces or exposes: wrong results, unhandled edge cases (empty, null, zero, boundaries, time zones, encodings), error paths that crash or swallow a failure, races and ordering, resource leaks, security holes (injection, missing authorization checks, secrets, unvalidated input), data loss or migrations that can't be rolled back, and breaking changes for existing callers. For each, quote the hunk, name the input or sequence that triggers it, and say what goes wrong. Mark a finding **likely bug** (hard) when you can name a concrete trigger, and **possible bug** (judgement call) when you can't. Report nothing you can't tie to a line of the diff. Under 400 words."

### 5. Aggregate

Present the three reports under `## Standards`, `## Spec` and `## Correctness` headings, verbatim or lightly cleaned. Do **not** merge or rerank findings, because the three axes are deliberately separate (see _Why three axes_).

Then a one-line summary: total findings per axis, and the worst issue _within each axis_ (if any). Don't pick a single winner across axes: that's the reranking the separation exists to prevent.

End with the **verdict** as the report's last line, exactly one of:

- `Verdict: pass`
- `Verdict: blocking (N hard findings)`

A hard finding is a breach of a documented repo standard, a spec requirement that is missing or implemented wrong, or a likely bug. Everything else (smells, code tells, test findings, slop, Drift, scope creep, possible bugs) is a judgement call and never blocks. A CI job can fail on a blocking verdict, so count only findings the sub-agents marked hard.

## Why three axes

A change can pass one axis and fail another:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**
- Code that matches the spec and the conventions but crashes on an empty list → **Correctness fail.**

Reporting them separately stops one axis from masking another.
