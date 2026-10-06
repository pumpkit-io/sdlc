# Credits

This skill is ported and adapted from the core `antislop` skill and the `antislop-ui` skill of [anti-slop](https://github.com/miqdadbadjuber/anti-slop) by Miqdad Badjuber (MIT), at commit `91f12ec67e9de6043cfd93b846404986ba73c3f4`. The UI slop patterns, the purpose test, the craftsmanship standard, the liveliness dials and levers, and the honesty rules in `HONESTY.md` come from there, rewritten in this repo's style: each pattern leads with the target behaviour, the numbered rules, install wizard, usage modes and pass/fail report are gone, and upstream's delivery checklist became a short self-check. Following `DESIGN.md` and reporting drift against it come from this repo's ADR 0003. This repo does not depend on or merge from anti-slop; this file carries the attribution.

`ACCESSIBILITY.md` and `scripts/contrast-check.py` are ported from upstream's `antislop-human` skill and its `contrast-check.py`, at the same commit. The script keeps upstream's WCAG 2.x formula, verdicts, exit codes and `--selftest`, which now reads the reference table from `ACCESSIBILITY.md`; the table gains a `#767676` row. Upstream's contrast MCP server and its launcher are not ported: the script and the hand formula in `ACCESSIBILITY.md` cover the same check in every agent.

Upstream copyright: Copyright (c) 2026 Miqdad Badjuber (antislop), MIT License.
