---
name: prose-style
description: Prose free of slop. Use when writing or editing prose people read (PR bodies, specs, tickets, agent briefs, handoffs, retros, docs, READMEs, ADRs, glossary entries, product copy), or when asked to make text sound less AI-generated.
---

# Prose Style

Write prose that says what it means in plain, specific words, so the reader gets the facts fast and never wonders whether a model padded it. The patterns below are the common ways generated prose turns into **Slop**. Each entry leads with the target behaviour; the tell is there so you can recognise it when editing.

Two rules govern every entry:

- **Every fact has a source.** A rewrite adds no fact, name, number, date, quote, link or claim that is not in the source text, the codebase, or what the user supplied. When a sentence needs a detail you don't have, ask for it, write a labelled placeholder (`[benchmark result]`), or write the plain sentence without it.
- **Keep a voice.** Prose stripped of every tell and left with no voice reads as machine-made too. When the user supplies a voice, match it (see [Voice](#voice)).

## Tone

### Specific words over impressive ones

Name what the thing does. The tell is abstract vocabulary stacked to impress: *unlock, elevate, empower, delve, showcase, testament, landscape, journey, robust, seamless, cutting-edge, game-changer, next-level*.

> Before: Unlock seamless collaboration to elevate your team's journey.
> After: Your team edits the same document at once.

### Claims sized to the evidence

State what changed and by how much, if you know. The tell is significance inflation: "a pivotal moment", "a new era of", "revolutionizing", "the future of X".

> Before: This refactor marks a pivotal moment for the billing module.
> After: Billing now has one entry point instead of four.

### Named sources

Attribute a claim to someone you can name, or state it as your own reasoning. The tell is a weasel attribution ("experts say", "people report", "industry observers") or social proof with nothing behind it ("trusted by thousands", "industry-leading").

> Before: Experts agree this pattern improves reliability.
> After: The retry wrapper stopped the three timeouts reported in #41.

### Straight to the point

Make the point in the first clause. The tells are persuasive-authority openers ("at its core", "the real question is", "fundamentally"), fake-candid pauses ("Honestly?", "Here's the thing"), and signposting ("Let's dive in", "Here's what you need to know").

> Before: Here's the thing: at its core, the bug is a race.
> After: The bug is a race between the two cache writers.

### End on the last fact

Stop when the content stops. The tells are chatbot closers ("I hope this helps!", "Let me know if you have any questions") and generic upbeat endings ("The future looks bright", "an exciting step forward").

### Emphasis in the wording

Let sentence structure carry the stress. The tell is ALL CAPS clauses doing the shouting inside a paragraph. A real heading, or a single capitalised word used once, is fine.

> Before: Run the migration first, OR THE DEPLOY WILL FAIL.
> After: Run the migration first. The deploy fails without it.

### A named actor

Say who did it when you know. The tells are the actorless passive ("the decision was made to drop v1") and an abstraction given a mind ("the data tells us", "the design decides", "the dashboard understands"). Passive is right when the actor is unknown or irrelevant ("the server restarted at 03:00"), and ordinary product verbs are fine ("the report shows", "the form submits").

> Before: The decision was made to drop the v1 endpoint.
> After: We dropped the v1 endpoint because no client has called it since March.

## Rhythm

### As many items as the content has

A list has the count the content requires. The tell is every idea forced into a trio: "speed, simplicity, and scale".

### Plain statements

State the claim directly. The tells are negative parallelism ("It's not just X, it's Y", "Not only X but also Y"), tacked-on fragments ("no guessing", "no surprises"), aphorism formulas ("X is the currency of Y"), and false ranges ("from first commit to final deploy, and everything in between").

> Before: It's not just a linter, it's a safety net. No guessing.
> After: The linter fails the build when a migration has no down step.

### Varied sentence length

Let sentences run long or short as the thought needs. The tell is staccato drama, a run of fragments built for a punchline: "No templates. No defaults. No safety." One short sentence for emphasis is fine.

### The same word for the same thing

Repeat the clearest word. The tell is synonym cycling, where "the checkout", "the process" and "the flow" all mean one thing. In technical prose this also breaks the glossary: use the project's term every time.

## Honesty

### Real specifics or none

Write a number, name, date or quote only when it is real. The tell is a fabricated specific that looks honest: an invented benchmark, a made-up user quote, a plausible version number. This is a defect even when it reads more human than the vague original.

> Before: Cuts build time by 40%.
> After, with a real measurement: Cuts CI build time from [measured before] to [measured after].
> After, without one: Removes the duplicate type-check step from the build.

### Gaps stated as gaps

When a fact is unknown, say so in one clause, or leave it out. The tell is speculative gap-filling: "the module was likely written for an older API", "the original author probably intended".

## Markdown hygiene

### Em-dashes rewritten

Write sentences that need no em-dash (U+2014). When editing, rewrite the sentence around each one into the punctuation it actually wants: a period for a new thought, a comma for a tight aside, a colon to introduce an explanation, parentheses for a true aside, or a conjunction. Never swap the character for a comma or hyphen blindly; read the sentence and restructure it. A spaced double hyphen (` -- `) standing in for one gets the same rewrite.

> Before: The cache [em-dash] which nobody owns [em-dash] is the bottleneck.
> After: The cache is the bottleneck, and nobody owns it.

### Bold for the one thing that matters

Bold a term only where the reader must not miss it, such as a glossary term on first use. The tell is every key noun bolded mechanically.

### Quotation marks for real quotes

Use quotes for dialogue, quoted sources, titles, and strings the reader types. The tell is scare quotes around ordinary words: the "solution" "streamlines" your "workflow".

### Lists whose items carry their own meaning

Write list items as plain statements, or fold short ones into a sentence. The tell is the inline-header list where the bold label restates the item: "- **Performance:** Load times are faster." Labels that name a fixed field of a template (`**Door:**`, `**Blast Radius:**`) are structure, not this tell.

### Headings without decoration

Headings carry words only. The tell is a decoration emoji leading a heading or bullet: 🚀 Launch, ✅ Next steps.

### Short phrasing

Use the short form: "to", "because", "now". The tells are filler phrases ("in order to", "due to the fact that", "it is important to note that") and stacked hedges ("could potentially possibly"). One qualifier does the work.

## What not to flag

A careful human writer hits several patterns above with no AI involved. When editing someone else's prose, these alone are not evidence of slop:

- Perfect grammar and a consistent style.
- Mixed casual and formal registers.
- Dry prose with none of the specific tells.
- Formal or precise vocabulary outside the list in [Specific words over impressive ones](#specific-words-over-impressive-ones).
- A single "however" or "additionally".
- Curly quotes, which most editors insert automatically.
- An em-dash on its own: many editors use them deliberately.
- One short emphatic sentence.
- An unsourced claim on its own.
- Secondhand text: quotations, titles, proper names, and phrases being discussed rather than used. Quoted text stays byte-identical.

Look for clusters. One tell means little; four in a paragraph is slop.

## Signs of human writing

Leave prose alone when it shows these. They are evidence of a person, and over-editing destroys them:

- Specific, unusual, hard-to-fabricate detail.
- Mixed feelings and unresolved tension.
- Era-bound references, slang and in-jokes.
- Real variety in sentence length.
- Genuine asides and self-corrections.

## Voice

The user's own writing (a sample, a draft, a quote, a commit message) is their voice, not agent prose. Edit it only when they ask, and then match it: read the sample first, note its sentence length, vocabulary, punctuation and recurring phrases, and keep its quirks instead of regularising them. The sample outranks this skill's style entries. If the sample uses em-dashes, name the conflict with the em-dash entry and ask whether to keep them; match their frequency only if the user says so.

## Self-check

Before handing over any prose, ask yourself, and fix what the answers turn up:

1. What in this reads as generated? Check the clusters above.
2. Does it state any fact, name, number, date, quote or claim that isn't in the source, the codebase, or what the user gave me?
3. Does it contain an em-dash (U+2014)? One hit means the draft isn't done.
4. Did I change any quoted text or the user's own voice without being asked?
