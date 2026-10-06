---
name: code-comments
description: Comments that say only what the code cannot. Use when writing or editing code comments, or when the user asks to clean up the comments in a file.
---

A comment earns its place by carrying something the code cannot show: the reason, the constraint, the non-obvious behaviour. Everything else is **Slop**. Write comments that way from the start; when cleaning existing ones, apply the same rules to every comment in scope.

## Scope guardrail

Only comments change. Executable code, identifiers, imports, formatting, indentation, whitespace, control flow and logic stay byte-identical. When removing a trailing comment, remove only the comment and the spaces before it. When the real fix is in the code (a confusing flow, a misleading name), leave the code alone: that is a smell for `code-review`, not a comment fix.

## Write these

Each entry leads with the target; the example after it is the slop it replaces.

- **Plain section labels, or none.** A label is one sentence-case line, kept only when it names something the code does not. Replaces banners and box-drawn headers: `// ======= ORDER PROCESSING =======`, `/* ---- ROUTES ---- */`.
- **Comments that add information.** When the line already says it, write nothing. Replaces restating: `// Initialize the variable` above `let count = 0`, `const userAge = 25; // User age is 25`, `// User class` above `class User {}`.
- **Code that shows its own flow.** Ordinary sequencing gets no comment; a flow too hard to follow is a structure problem, not a missing comment. Replaces step narration: `// Step 1: Validate input`, `// Step 2: Process request`, `// First...`, `// Finally...`.
- **Labels that carry a fact.** "Note: retries happen only on 5xx" stays. Replaces empty labels: `// Main logic`, `// Helper function`, `// Error handling`, `// Note: this is important`.
- **TODOs that name a task.** A TODO says what to do and why, with enough context to act on (a ticket reference, a condition). Replaces vague placeholders: `// TODO: Improve this`, `// Add more validation`, `// Future improvements`.
- **Docs that go beyond the signature.** Keep documentation of business rules, edge cases, assumptions, algorithms, limitations, side effects, API behaviour and security implications. Remove the parts that only echo the name and parameters: `@param price The price.`, `@returns Total price.` A doc block that is pure echo goes entirely.
- **Plain words.** Replaces decorative emoji: `// ✅ Validation`, `// 🚀 Performance`.
- **Closing braces that end their own blocks.** Replaces end markers: `} // end if`, `# End of function`. Keep one only in a block long enough that the marker prevents real confusion.
- **One comment per logical block.** If the block needs none, write none. Replaces line-by-line narration: `// Loop items`, `// Get item`, `// Increment`, `// Return result` on consecutive lines.
- **Short, sentence-case lines in a developer's voice.** `// Validate credentials before issuing a token.` Replaces stiff or loud wording: "This function is responsible for validating whether the supplied credentials are valid before continuing with the authentication process", `// MAIN LOGIC`.

## Keep these

Comments that explain any of the following stay, in substance:

- business logic and intent
- architectural decisions
- security considerations
- performance trade-offs
- concurrency behaviour
- protocol details
- API contracts
- workarounds
- edge cases and assumptions
- licensing and legal notices

```js
// Stripe may retry webhook deliveries for up to three days.
// Ignore duplicate events using the event ID.
```

## Length

Every comment is one line. A second line is allowed only when it carries a new fact, as in the Stripe example; never three. Keeping a comment says what may stay, not how long it may run: a valuable comment is where over-explaining hides. Cut it to the constraint alone (the platform trap, the silent failure, the protocol rule, the cost) and drop the issue number, the version history and the "because X, so Y, therefore Z" chain.

## Self-check

Before finishing, check each comment you wrote or kept:

- It says something the code does not.
- It is one line, or two with a new fact on the second.
- It reads as a short note from an engineer, in sentence case.
- Every preserved kind above is still there.
- Outside comments, the diff is empty.
