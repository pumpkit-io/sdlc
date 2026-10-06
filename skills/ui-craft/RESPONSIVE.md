# Responsive layout

A layout reflows from phone to desktop: at each width where the content stops working it re-stacks, rescales and re-orders on purpose. The phone view is a layout of its own, designed and checked, never the desktop view at a smaller size. When `DESIGN.md` sets a spacing or type scale, the narrow states use its smaller steps.

Each entry leads with the target; the example after it is the failure it replaces.

## Breakpoints

- **A designed narrow state.** Below the width where the content stops working, columns stack, sizes drop and the order changes where the content needs it. Replaces one layout for every screen, squeezed until cards overlap and wide-canvas text crowds a phone.
- **Breakpoints set by the content.** Narrow the viewport, watch where a column stops being readable or a card row gets too tight, and put the breakpoint there. Replaces breakpoints copied from a device list (375, 414, 768 px) because "that is the iPhone size".
- **Narrow widths styled as a state, not a patch.** The narrow viewport gets its own deliberate sizes and stacking, and the whole layout is checked there. Replaces a long desktop stylesheet with one trailing media query fixing the bug someone reported.
- **As many states as the content needs.** A typical reflow has three: one column, then two when a single stack gets too wide, then the full grid only where it fits. The band from roughly 600 to 1024 px (tablets, small laptops) is designed, not inherited. Replaces exactly two states, so the middle widths get either the phone stack stretched wide or the desktop grid crammed small.

## Scale

- **A smaller size step on narrow screens**: type, section padding, gaps and card sizes all drop at the breakpoint, while tap targets keep their minimum. Replaces desktop padding, gaps and hero heights carried unchanged, so every section looks blown up on a phone.
- **Type that responds to the viewport**: fluid sizes with `clamp()`, or a smaller type step at the breakpoint. Replaces fixed `px` sizes that leave a headline spanning the whole phone.
- **Sections sized by their content** (`height: auto`), with `dvh` where a full-height section is the intent. Replaces `100vh` heroes that become a slab on a phone and overflow the visible area, because `vh` counts the browser chrome.
- **Section padding in a mobile register**, roughly half the desktop value or less, so the page scrolls at a natural density. Replaces 96 or 128 px of desktop padding kept on mobile, a tall empty gap between every section.

## Grids and stacking

- **Grids that collapse**: at the breakpoint, side-by-side columns stack into one, and each item gets the full width back. Replaces columns that keep their places on a phone, each shrunk to a sliver with text wrapping word by word and cards colliding.
- **Fluid tracks**: `minmax()`, `auto-fit` and `auto-fill`, so columns shrink and wrap with the content, and grid areas that collapse at the breakpoint. A fixed size appears only where it is deliberate. Replaces `grid-template-columns` in fixed `px`, a grid that keeps its shape and forces overflow.
- **Columns that follow the content.** On a phone the content usually wants one column, two at most. Replaces a 12-column grid forced onto mobile content, with arbitrary spans fitting the content to an invisible grid.

## Overflow

- **Zero horizontal scroll at the narrowest width.** Find whatever is wider than the viewport and contain or reflow it: a table gets a reflowed layout or its own scroll container, a code block wraps or scrolls inside itself, images get `max-width: 100%`, long unbroken strings break. Replaces a page that scrolls sideways because one element spills past the edge, unnoticed in a desktop preview.
- **Content that fits instead of being clipped**: the container grows, its content wraps, or it collapses at the breakpoint. Clip only where cropping is the design (a thumbnail). Replaces `overflow: hidden` cutting off text or controls at narrow widths.
- **Children that can shrink with their parent**: relative widths, `flex-wrap`, and `min-width: 0` on grid and flex children. Replaces a child with a fixed `px` width or `min-width` that bursts out of its container and the page.

## Tap targets

- **Targets at least 44 by 44 px**, using padding or a larger hit area when the visible control is smaller. Replaces 16 px links and icon buttons that a cursor hits easily and a thumb misses.
- **A clear gap between adjacent targets**, so a thumb press on one never lands on the next. Replaces large targets packed edge to edge, which behave like one control.
- **A tap equivalent for every hover interaction**: a menu that opens on hover also opens on tap, a reveal also shows on click, and controls show `:active` feedback so a tap registers. Replaces menus, reveals and tooltips that exist only on hover, unreachable on a touchscreen.

## Navigation

- **Navigation that reflows into a mobile pattern** at the breakpoint: a bottom bar for the handful of primary destinations, a menu for the rest, the primaries one thumb tap away. Replaces the desktop row of links kept on a phone, crowding, wrapping to two rows or spilling past the edge.
- **A menu people can find**: label the menu button ("Menu"), or keep the primary destinations visible and tuck only the secondary ones away. Replaces a bare hamburger icon hiding every destination, including the only way around the app.
- **Space reserved for fixed bars**: page padding equal to the bar's height, plus `env(safe-area-inset-*)` where the device has notches or a home indicator, so the last item and the final button stay reachable. Replaces a fixed bottom bar sitting over the end of the list or the form the user is finishing.
- **Compact fixed chrome**: sticky headers and bottom bars stay small enough that the content dominates, shrinking or hiding on scroll where it suits the product. Replaces a tall sticky header that letterboxes the phone screen.

## Self-check

Before handing over a layout, ask yourself, and fix what the answers turn up:

1. Dragging the viewport from the narrowest target to desktop width, where does the layout break, crowd, stretch or collide? Check the middle band, not just phone and desktop.
2. At the narrowest width, is there any horizontal scroll, clipped content, oversized type or padding, or a grid that didn't collapse?
3. Is every control at least 44 by 44 px with a gap from its neighbours, and does every hover interaction work by tap?
4. Does the navigation reflow, is the menu discoverable, and is every fixed bar clear of the content beneath it?
5. Did I check it at narrow widths in a browser, or say why I couldn't and check by reading the styles?
