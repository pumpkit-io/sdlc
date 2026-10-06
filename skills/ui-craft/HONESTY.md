# Honest UI content

Everything a UI presents as fact comes from real information or is a placeholder that reads as one. A page that shows invented numbers, people or claims lies to whoever looks at it, and in a prototype it lies to the person judging the design. This file stands on its own: `prototype` reads it without the rest of `ui-craft`.

## The rule

Every number, claim, testimonial, name, logo, link and data row on screen has a source: the codebase, real data the screen fetches, or what the user supplied. When a value has no source, ask for it if the user is around; otherwise write a placeholder that says what belongs there (`[REAL DATA]`, `[LOGO]`, "Coming soon"), or leave the element out. An empty section beats a fabricated one.

A placeholder looks like a placeholder. Brackets, a label or a visibly neutral style make it obvious to anyone looking at the screen; a placeholder dressed as final content (a plausible number in the real stat style) is a fabrication.

## What it looks like

Each entry leads with the honest version; the example after it is the fabrication it replaces.

- **Numbers with a source, or none.** Stats, metrics and deltas come from real data. A delta ("+12% this week") appears only when the comparison period is real and named. Replaces `10K+ users`, `99.9% uptime`, `120+ countries`, and dashboard stat cards reading `12,483 / 94.2% / $48.2K`.
- **Testimonials from real people, or no testimonials section.** Replaces random names, invented job titles, AI-generated avatars and fictional reviews.
- **Claims you can back.** Security, compliance and performance claims appear only with evidence the user supplied. Replaces "SOC 2 compliant", "ISO 27001", "enterprise-grade security", "300% faster".
- **Customer logos for real customers.** Replaces the generic "Trusted by" logo bar under the hero.
- **Activity that happened.** A feed or history shows real events, or an honest empty state that says what to do first. Replaces "Sarah Chen updated a document, 2 hours ago" on rotation.
- **Empty fields and cells stay empty, or say what goes there.** Use `Your name`, `email@example.com`, `Write your message`, or `[REAL DATA]` where a value is expected. Replaces plausible filler: `John Doe`, `johndoe@example.com`, phone numbers and dates that belong to nobody.
- **FAQ questions your users actually ask.** When you don't know them, leave the FAQ out. Replaces template questions ("Is my data secure?", "Can I cancel anytime?").
- **A product shown working, or an honest "not shipped yet".** A page that takes signups or payment links real Terms of Service and a Privacy Policy. Replaces a page that sells a product it never shows, with no legal pages behind it.
- **Assets the user asked for.** Before creating a logo, app icon, avatar, team photo or any image of a person, ask; when you can't, use the product name set as text or `[LOGO]` for a logo, and initials or a plain shape for an avatar. Replaces generated logos and portraits presented as final. When the user already gave explicit instructions, build the asset directly.

## Self-check

Before handing over the UI, ask yourself, and fix what the answers turn up:

1. Is there a number, name, quote, logo, claim or data row on screen whose source I can't name?
2. Would someone looking at the screen tell every placeholder apart from real content?
