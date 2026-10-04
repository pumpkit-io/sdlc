---
name: improve-codebase-architecture
description: Scan a codebase for deepening opportunities, present them as a visual HTML report, then grill through whichever one you pick.
disable-model-invocation: true
---

# Improve Codebase Architecture

Surface architectural friction and propose **deepening opportunities**: refactors that turn shallow modules into deep ones. The aim is testability and AI-navigability.

This command is _informed_ by the project's domain model and built on a shared design vocabulary:

- Load the `codebase-design` skill for the architecture vocabulary (**module**, **interface**, **depth**, **seam**, **adapter**, **leverage**, **locality**) and its principles (the deletion test, "the interface is the test surface", "one adapter = hypothetical seam, two = real"). Use these terms exactly in every suggestion, and don't drift into "component," "service," "API," or "boundary."
- The domain language in `GLOSSARY.md` gives names to good seams; ADRs in `docs/adr/` record decisions this command should not re-litigate.

## Process

### 1. Explore

**Scope before you scan: YAGNI.** Deepening a module pays off by making future changes to it easier, so put extra weight on the parts of the codebase that have recently changed. Decide *where* to look before you look:

- If the user named a direction (a module, a subsystem, a pain point), take it, and skip the inference below.
- Otherwise, walk back a good stretch of the commit history (`git log --oneline`) to find the codebase's hot spots, the files and areas that keep coming up, and let those paths pull your attention first. If the changes are scattered with no clear hot spot, widen the net.

Read the project's domain glossary (`GLOSSARY.md`) and any ADRs in the area you're touching first.

Then spawn a sub-agent to walk the codebase (if your agent can't spawn sub-agents, walk it yourself). Don't follow rigid heuristics; explore organically and note where you experience friction:

- Where does understanding one concept require bouncing between many small modules?
- Where are modules **shallow**, with an interface nearly as complex as the implementation?
- Where have pure functions been extracted just for testability, but the real bugs hide in how they're called (no **locality**)?
- Where do tightly-coupled modules leak across their seams?
- Which parts of the codebase are untested, or hard to test through their current interface?

Apply the **deletion test** to anything you suspect is shallow: would deleting it concentrate complexity, or just move it? A "yes, concentrates" is the signal you want.

### 2. Record candidates, then present them as an HTML report

Each candidate gets two renderings: a markdown doc in the repo that an agent can read cold, and an HTML report for the user to look at. Write the doc first; the HTML draws its content from it.

**Use GLOSSARY.md vocabulary for the domain, and the `/codebase-design` vocabulary for the architecture**, in both. If `GLOSSARY.md` defines "Order," talk about "the Order intake module," not "the FooBarHandler," and not "the Order service."

**ADR conflicts**: if a candidate contradicts an existing ADR, only surface it when the friction is real enough to warrant revisiting the ADR. Say so plainly in the candidate (e.g. _"contradicts ADR-0007, but worth reopening because…"_). Don't list every theoretical refactor an ADR forbids.

#### The candidates doc

Write `docs/architecture-improvements/<scope>-YYYY-MM-DD.md` in the target repo, where `<scope>` is a kebab-case name for the area you scanned (the repo's name for a whole-repo scan). Create the directory if it doesn't exist, and add `docs/architecture-improvements/` to the repo's `.gitignore` unless a line there already covers it.

The doc is a **handoff**: a fresh agent session must be able to pick up any single candidate from its section alone, with neither this session nor the HTML. Plain prose, no diagrams. Structure it as:

- **Header**: the scope scanned, the date, the current commit SHA (so a later reader can judge staleness), and one line for the reader: _"To explore a candidate, load the `grilling`, `codebase-design` and `domain-modeling` skills, then grill through that candidate's section."_
- **One `##` section per candidate**, each self-contained:
  - **Files**: which files/modules are involved
  - **Problem**: why the current architecture is causing friction
  - **Solution**: plain English description of what would change
  - **Benefits**: explained in terms of locality and leverage, and how tests would improve
  - **Recommendation strength**: one of `Strong`, `Worth exploring`, `Speculative`
  - **Dependency category**: from the `codebase-design` skill's dependency categories, and what that means for testing across the seam
  - **ADR conflicts**: the ADR and why it's worth reopening, or "none"
  - **Interactions**: how this candidate overlaps, enables, or conflicts with the others, restating what the reader needs about each one, since the reader may open only this section
- **Top recommendation**: which candidate you'd tackle first and why.

#### The HTML report

Write a self-contained HTML file to the OS temp directory: it is for viewing, so it stays out of the repo. Resolve the temp dir from `$TMPDIR`, falling back to `/tmp` (or `%TEMP%` on Windows), and write to `<tmpdir>/architecture-review-<timestamp>.html` so each run gets a fresh file. Open it for the user (`xdg-open <path>` on Linux, `open <path>` on macOS, `start <path>` on Windows).

The report uses **Tailwind via CDN** for layout and styling, and **Mermaid via CDN** for diagrams where a graph/flow/sequence reliably communicates the structure. Mix Mermaid with hand-crafted CSS/SVG visuals: use Mermaid when relationships are graph-shaped (call graphs, dependencies, sequences), and hand-built divs/SVG when you want something more editorial (mass diagrams, cross-sections, collapse animations). Each candidate gets a **before/after visualisation**. Be visual.

For each candidate, render a card with the doc's Files, Problem, Solution and Benefits, plus:

- **Before / After diagram**: side-by-side, custom-drawn, illustrating the shallowness and the deepening
- **Recommendation strength**, rendered as a badge
- **ADR conflict**, if any, as a warning callout

End the report with the doc's **Top recommendation**.

See [HTML-REPORT.md](HTML-REPORT.md) for the full HTML scaffold, diagram patterns, and styling guidance.

Do NOT propose interfaces yet. Once both files are written, tell the user both absolute paths and ask: "Which of these would you like to explore?"

### 3. Grilling loop

Once the user picks a candidate, load the `grilling` skill to walk the decision tree with them: constraints, dependencies, the shape of the deepened module, what sits behind the seam, what tests survive.

When the user wants to explore several candidates, offer the alternative: grill each one in its own fresh session, pointed at that candidate's section of the doc, so earlier candidates don't crowd the context. Grilling here remains fine.

Side effects happen inline as decisions crystallize; load the `domain-modeling` skill to keep the domain model current as you go:

- **Naming a deepened module after a concept not in `GLOSSARY.md`?** Add the term to `GLOSSARY.md`. Create the file lazily if it doesn't exist.
- **Sharpening a fuzzy term during the conversation?** Update `GLOSSARY.md` right there.
- **User rejects the candidate with a load-bearing reason?** Offer an ADR, framed as: _"Want me to record this as an ADR so future architecture reviews don't re-suggest it?"_ Only offer when the reason would actually be needed by a future explorer to avoid re-suggesting the same thing; skip ephemeral reasons ("not worth it right now") and self-evident ones.
- **Want to explore alternative interfaces for the deepened module?** Load the `codebase-design` skill and use its design-it-twice pattern.
