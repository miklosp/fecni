# Shortcuts hint — Liquid Glass morphing pill — design spec

**Date:** 2026-05-30
**Status:** approved (design); implementation pending

## Purpose

Replace the capture editor's keyboard-shortcuts affordance with a single
**Liquid Glass pill** that morphs between two states:

- **Collapsed** — a small circular glass pill showing the `keyboard` glyph,
  pinned to the editor's bottom-right corner.
- **Expanded** — the same pill stretched leftward into a wide capsule listing
  the editor's keyboard shortcuts, ending in a close button.

The pill is anchored to the bottom-right; because the right edge is fixed, the
capsule **grows organically leftward** over the editor as it opens, and the
trailing glyph stays put and **cross-fades `keyboard` → a circled ✕**. This is
the "keyboard morphs into (x)" behavior.

Replaces the current `ShortcutsFooter` (a `Divider` + `LazyVGrid` that reflowed
the editor) and the separate bottom-right keyboard toggle button.

## Constraints & decisions

- **Platform:** macOS 26.3 target, Swift 6.2, SwiftUI. The Liquid Glass APIs
  (`GlassEffectContainer`, `glassEffectID(_:in:)`, `glassEffect(_:in:)`) are
  macOS 26.0+, so the target supports them.
- **Implementation approach:** one glass capsule whose *width* animates,
  right-anchored, with the full content trailing-aligned inside it and clipped
  to the capsule. Growing the width unmasks the hints right-to-left; nothing
  slides. (Chosen over animating layout — sliding chips/the button looked bad
  and let content escape the glass surface.)
- **Shortcuts shown:** `⌘1/2/3 Heading`, `⌘B Bold`, `⌘I Italic` — in that
  order (matches the mockup). These are the only shortcuts wired to the
  MarkdownEngine bus; lists remain right-click-only and are intentionally not
  advertised here.

## Component & placement

- New view **`ShortcutsHint`** in `fecni/ShortcutsHint.swift`.
- Attached as `.overlay(alignment: .bottomTrailing)` on the editor inside
  `CaptureView`, with ~12pt inset. It **floats over** the text and never
  reflows the editor (unlike the old footer).
- Owns its expand state as local `@State private var isExpanded` — this is
  transient UI state, not document state, so it does **not** live on
  `CaptureModel`. `CaptureModel.showFooter` is removed.

## States & the morph (unmask, not slide)

The full content — shortcut chips followed by the trailing toggle button — is
always laid out at its natural width (`.fixedSize()`), **trailing-aligned**
inside a frame whose width animates. Because the frame is right-anchored (via
the bottom-trailing overlay) and the content's right edge is pinned, the content
**never moves**. A `.clipShape(.capsule)` over the glass reveals only the
rightmost `width` points of it.

- **Collapsed (`width = 50`):** the clip shows only the trailing button, so the
  pill reads as a small glass circle with the `keyboard` glyph. The whole pill
  is the expand tap target.
- **Expanded (`width =` measured full content width):** the capsule has grown
  left far enough to reveal every chip. Chips are `keys` (monospaced caption) +
  `label` (secondary caption), in the order `⌘1/2/3 Heading`, `⌘B Bold`,
  `⌘I Italic`.
- **Growing the width unmasks the chips right-to-left** — `⌘I Italic` appears
  first (nearest the button), `⌘1/2/3 Heading` last. The chips do not slide.
- The toggle glyph is a **separate overlay pinned to the trailing edge**, not
  part of the clipped, growing track — so it is structurally incapable of
  moving with the reveal. It only morphs `keyboard` ⟷ a circled-✕ in place via
  `.contentTransition(.symbolEffect(.replace))` (`xmark.circle.fill`,
  secondary-tinted — exact symbol is a visual tuning detail). The track carries
  a trailing `Color.clear` spacer the width of the glyph so revealed chips never
  slide under it.
- The full content width is measured once with `.onGeometryChange`. The toggle
  runs in `withAnimation(.spring(...))`; spring parameters are a tuning detail.
- **Modifier order matters:** the content is `.clipShape(.capsule)`d *before*
  `.glassEffect(…, in: .capsule)`, so the material is applied last (outermost)
  and is never clipped away. The track is wrapped in a `GlassEffectContainer`
  for correct material rendering. (`glassEffectID` is still unused — there's
  only one glass shape and no shape-to-shape morph.)

## Interaction model

- **Collapsed pill:** entire pill is one tap target → expands.
- **Close (✕):** the only control that collapses the pill back. Chips are
  passive labels with no tap behavior.
- **Esc:** unchanged — dismisses and saves the whole capture
  (`model.requestDismiss()`); the pill does **not** intercept it.
- **Click-away:** unchanged — resigning key still saves & closes the panel.
  Clicking into the editor does **not** auto-collapse the pill (deliberate v1
  simplification; an auto-collapse tap-catcher is a possible later enhancement).
- **Reduce Motion:** when `accessibilityReduceMotion` is set, skip the spring
  and toggle instantly.
- **Accessibility:** keep `.help("Keyboard shortcuts")`; VoiceOver label
  reflects collapsed/expanded state.

## Files changed

- **`fecni/ShortcutsHint.swift`** (new) — the morphing glass pill.
- **`fecni/ShortcutsFooter.swift`** — deleted (superseded).
- **`fecni/CaptureView.swift`** — remove the bottom `HStack` keyboard button and
  the `if model.showFooter { ShortcutsFooter() }` branch; add the `.overlay`
  and the `@Namespace`; remove `showFooter` from `CaptureModel`.

## Verification

No new pure-logic to unit-test (`CaptureKit` untouched; app-hosted XCTest is
broken on this toolchain). Verification is **build + run + observe** via the
`xcode-build` skill:

1. Builds cleanly (Debug).
2. Summon the capture panel; pill appears collapsed bottom-right.
3. Click → expands leftward with the glass morph; `keyboard` cross-fades to ✕;
   chips appear in mockup order.
4. Click ✕ → collapses back to the keyboard pill.
5. With Reduce Motion on, the toggle is instant (no spring).
6. Esc and click-away still save & close the capture.
