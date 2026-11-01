# Accessible UI

A UI holds up when people with different eyes, hands and setups can use it: low vision, colour blindness, keyboard only, screen readers, 200% zoom, bright sunlight. Each entry leads with the target; the example after it is the pattern that excludes someone.

## Contrast

Every ratio you claim has a number behind it, from the checker below. The eye overestimates contrast, worst of all on grey pairs, so a pairing judged by eye is unverified.

- **Text at 4.5:1 or more against its background, large text at 3:1.** Large text is at least 24px, or 19px bold. Replaces light grey body text and muted labels picked because they look elegant.
- **Text over a photo or gradient checked at its worst spot.** Contrast is local: where the image turns light, white text drops below 4.5:1 while the hero still looks fine. Put a scrim or a solid block behind the text, then check the lightest area the text crosses. If any part fails, the treatment fails. Replaces a check at one dark spot.
- **Grey pairs computed.** `#555555` on black is 2.82:1 and fails. Replaces "dark grey on black passes AA", asserted without a computation.
- **Controls and status indicators at 3:1 against adjacent colours** (WCAG 1.4.11): button edges, input borders, icons, focus rings, chart segments, and their hover and selected states. Icons carry a text label at 4.5:1. Replaces a component whose edge is a hair of tint.

### Checking a ratio

With Python available, run the checker in this skill's folder (`python` instead of `python3` on Windows):

```bash
python3 scripts/contrast-check.py "#777777" "#FFFFFF"
# ratio: 4.48:1
# normal text (4.5:1): FAIL
# large text  (3.0:1): PASS
```

It takes two hex colours in either order (`#RRGGBB`, `RRGGBB` or `#RGB`) and exits 0 when both verdicts pass, 1 when either fails, 2 on bad input.

Without Python, or when the script is missing, compute the ratio by hand with the WCAG 2.x formula. The script implements exactly this:

1. For each colour, take each channel as `c = value / 255`.
2. Linearize it: if `c <= 0.03928`, `c_lin = c / 12.92`; otherwise `c_lin = ((c + 0.055) / 1.055) ^ 2.4`.
3. Relative luminance: `L = 0.2126 * R_lin + 0.7152 * G_lin + 0.0722 * B_lin`.
4. Ratio: `(L1 + 0.05) / (L2 + 0.05)`, with `L1` the lighter luminance and `L2` the darker. It runs from 1:1 to 21:1 (black on white).
5. Compare the unrounded ratio with 4.5 for normal text and 3.0 for large text; round to two decimals only to report it.

Common pairings, as a sanity check for your own arithmetic:

| Pairing (text on background) | Ratio | Normal text (4.5) | Large text (3.0) |
|------------------------------|-------|-------------------|------------------|
| Black on white | 21.00 | Pass | Pass |
| White on black | 21.00 | Pass | Pass |
| White on #333333 | 12.63 | Pass | Pass |
| White on #666666 | 5.74 | Pass | Pass |
| #767676 on white | 4.54 | Pass | Pass |
| #777777 on white | 4.48 | Fail | Pass |
| White on #888888 | 3.54 | Fail | Pass |
| White on #999999 | 2.85 | Fail | Fail |
| #555555 on black | 2.82 | Fail | Fail |

A pairing not in the table, or one near a threshold, goes through the script or the formula. `python3 scripts/contrast-check.py --selftest` recomputes every row above; run it after editing the table.

## Keyboard

- **A visible focus style on every interactive element.** Keep the browser outline, or replace it with a `:focus-visible` style at 3:1 against its neighbours. `outline: none` always comes with its replacement in the same rule set. Replaces `outline: none` or `outline: 0` with nothing in its place, which leaves keyboard users unable to see where they are.
- **Every control reachable and operable from the keyboard.** Tab reaches it, Enter or Space activates it, Escape closes dialogs and menus. Menus open on focus or click as well as hover; drag and drop has a keyboard alternative. Replaces hover-only menus, dropdowns that open only on click, and drag-only reordering.
- **Tab order that follows the visual order.** Source order matches what the eye reads, long pages get a skip link, and `tabindex="-1"` appears only inside a controlled focus trap such as a dialog. Replaces focus that jumps around the page, skips content or lands on hidden elements.

## Focus and states

- **A focus indicator that holds in every theme**: 3:1 against adjacent colours, at least as thick as a 1px border, shown on focus and not only on hover. Check it in light and dark mode. Replaces a ring the same colour as the background.
- **Every colour signal paired with text, an icon or a pattern.** Errors are text first: "Password must be at least 8 characters", with the red border as support. Replaces status shown only by hue (red text, a green border, a tinted chip), which disappears for colour-blind users and in forced-colors mode.
- **Empty, loading and error states people can perceive.** A spinner carries text ("Loading invoices"), and state changes are visible or announced to screen readers. Replaces a bare spinner that a screen-reader user hears as a frozen page.

## Zoom and the on-screen keyboard

- **Text that survives 200% zoom** (WCAG 1.4.4): sizes that scale with the user's settings, and no `overflow: hidden` container that clips text. Check at 200% on a narrow viewport. Replaces fixed pixel type in clipping containers.
- **A focused input that stays visible above the on-screen keyboard.** It scrolls into view, with enough bottom padding that the keyboard never covers it. Test on a device or an emulated keyboard. Replaces inputs at the bottom of the viewport hidden behind the keyboard.

## Self-check

Before handing over the UI, ask yourself, and fix what the answers turn up:

1. Which text and background pairs did I check with the script or the formula, including text over images and gradients? Any pair I only looked at is still unchecked.
2. Do control edges, icons and status indicators reach 3:1 against what surrounds them?
3. Can I reach and operate every control from the keyboard alone, in visual order, and see where focus is in every theme?
4. Is every colour signal backed by text or an icon, and is every empty, loading and error state perceivable?
5. Does the text hold at 200% zoom, and does the on-screen keyboard leave a focused input visible?
