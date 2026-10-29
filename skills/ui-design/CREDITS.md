# Credits

## frontend-design

`SKILL.md` from its top down to "More on writing in design" is Anthropic's `frontend-design` skill, from [anthropics/skills](https://github.com/anthropics/skills) at commit `ca45fc496a3436251f191354091d557da31c15b5` (the same text ships as version 1.1.1 of the `frontend-design` Claude Code plugin), under the Apache License 2.0 in [LICENSE.txt](LICENSE.txt). Changes from upstream: the skill is named `ui-design`, its description gains a "Use when" trigger list, the top heading is renamed, and the "Working in a repo" section is added at the end. Everything in between is copied word for word, so it is the one part of this repo that does not follow the `prose-style` skill: its results are why the skill is here, and rewording it would risk them. To port an upstream change, diff `skills/frontend-design/SKILL.md` in anthropics/skills from that commit and apply it by hand.

## anti-slop

The "Working in a repo" section keeps what used to be this repo's `ui-craft` skill, ported and adapted from the core `antislop` skill and the `antislop-ui` and `antislop-layoutmobile` skills of [anti-slop](https://github.com/miqdadbadjuber/anti-slop) by Miqdad Badjuber (MIT), at commit `91f12ec67e9de6043cfd93b846404986ba73c3f4`. The craftsmanship standard behind the quality floor, the honesty rules in `HONESTY.md`, and the responsive layout rules in `RESPONSIVE.md` (from `antislop-layoutmobile`) come from there, rewritten in this repo's style. `ui-craft`'s slop pattern list and liveliness dials are gone: `frontend-design` covers the same ground with its own calibration list and its rule to spend boldness in one place. Following `DESIGN.md` and reporting drift against it come from this repo's ADR 0003. This repo does not depend on or merge from anti-slop; this file carries the attribution.

`ACCESSIBILITY.md` and `scripts/contrast-check.py` are ported from upstream's `antislop-human` skill and its `contrast-check.py`, at the same commit. The script keeps upstream's WCAG 2.x formula, verdicts, exit codes and `--selftest`, which now reads the reference table from `ACCESSIBILITY.md`; the table gains a `#767676` row. Upstream's contrast MCP server and its launcher are not ported: the script and the hand formula in `ACCESSIBILITY.md` cover the same check in every agent.

Upstream copyright: Copyright (c) 2026 Miqdad Badjuber (antislop), MIT License.
