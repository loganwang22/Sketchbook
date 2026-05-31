# Sketchbook v1 — Manual On-Device Test Plan

Run these on a real iPad (any model running iPadOS 26+) with an Apple Pencil before any release. The simulator is fine for chrome/UI smoke tests, but pressure, tilt, and palm rejection only work on real hardware.

## Drawing fundamentals
- [ ] Pencil produces a stroke; finger does NOT produce a stroke (default).
- [ ] Pen brush stroke width visibly varies with Pencil pressure.
- [ ] Crayon brush shading visibly varies with Pencil tilt (Pencil 2 / Pro).
- [ ] Marker brush overlapping strokes darken where they cross.
- [ ] Paintbrush (watercolour) has soft, semi-transparent edges.
- [ ] Eraser removes pixels but leaves surrounding strokes intact.
- [ ] Pinch-zoom with two fingers works; pencil drawing during zoom does not break the stroke.
- [ ] Palm resting on screen during pencil drawing leaves no marks.

## UI
- [ ] Selected brush is enlarged (~1.2×) and lifted compared to others.
- [ ] Re-tapping selected brush blooms the 3-size selector above it.
- [ ] Long-press on a palette colour opens the full colour wheel; the picked colour appears in the custom slot.
- [ ] All 10 default palette colours are muted (no neon).
- [ ] Background colour from "⋯ → Background" updates the canvas live.
- [ ] Undo / Redo arrows respond to taps and update enabled/disabled state after strokes.
- [ ] Finger-drawing toggle: turning on requires the parent gate; turning off is one tap.

## Photo features
- [ ] Camera button → parent gate → camera opens → snap a photo → mode sheet appears.
- [ ] Photos button → parent gate → PHPicker opens → pick a photo → mode sheet appears.
- [ ] Starter button (no gate) → 6 SF-symbol starter images visible → pick one → mode sheet appears.
- [ ] "Look at it" pins the photo so the drawing area is unaffected.
- [ ] "Trace it" places the photo as 40 % opacity background under the canvas.
- [ ] "Colour it in" produces visible black line art on white.

## Persistence & export
- [ ] Draw → back → reopen → strokes still there.
- [ ] App backgrounded → foregrounded → drawing intact and editable.
- [ ] Share → parent gate → share sheet shows; **Save to Photos** succeeds and the saved image matches the canvas.
- [ ] Print via the share sheet renders correctly on AirPrint.

## Parent gate
- [ ] Single-finger tap-and-hold on one dot never passes the gate.
- [ ] Two simultaneous fingers don't pass.
- [ ] Three fingers held for ~3 seconds passes the gate (subtle progress ring fills around each dot).
- [ ] Lifting any finger before 3 seconds resets all progress rings to zero.

## Misc
- [ ] App locked to iPad (no iPhone variant in App Store Connect).
- [ ] Launching with empty `Documents/Drawings/` shows an empty gallery with the "+" tile.
- [ ] Long-press a thumbnail → cells wiggle → "−" appears → tap → parent gate → drawing disappears and its folder is removed from `Documents/Drawings/<uuid>`.
- [ ] Switching between portrait and landscape mid-drawing doesn't lose strokes or break the chrome layout.
