# Sketchbook — Design Spec

**Date:** 2026-05-27
**Author:** Logan Wang (brainstormed with Claude Code)
**Target platform:** iPadOS 17+, Apple Pencil
**Audience:** Kids aged 4–10

---

## 1. Vision

A minimalist, kid-friendly sketchbook for iPad. The whole app is a free-form drawing playground — no goals, no levels, no tutorials. The drawing tool itself is the experience. The UI is simple by default and reveals depth on long-press, so it serves a non-reading 4-year-old and a curious 10-year-old with the same interface.

## 2. Design principles

- **The canvas is the hero.** Chrome is small, floating, and quiet.
- **One tap to act, one long-press for depth.** No hamburgers, no nested menus.
- **No reading required.** Iconography over labels. Long-press is the only "hidden" interaction.
- **Quiet polish.** No sound effects, particles, or animations beyond standard iOS UI transitions. Drawing itself is the fun.
- **Pencil is for drawing; fingers are for navigating.** Palm rejection on by default.
- **Parents control destructive and privacy-sensitive actions** via a tap-and-hold three-dot gate.

## 3. Architecture

### 3.1 Technology stack

- **Language:** Swift 5.10+
- **UI:** SwiftUI for chrome + gallery; `PKCanvasView` (UIKit, wrapped in `UIViewRepresentable`) for the drawing surface
- **Drawing engine:** PencilKit
- **Image processing:** Core Image (for the "Color it in" photo-to-coloring-page pipeline)
- **Persistence:** Filesystem (`FileManager`) — JSON metadata + PNG assets per drawing in the app's `Documents` directory. No Core Data, no SwiftData, no CloudKit in v1.
- **Minimum iOS:** 17.0 (required for `PKInkingTool.InkType.crayon` and `.watercolor`)

### 3.2 Why PencilKit + custom SwiftUI shell (vs. alternatives)

A custom drawing engine (Metal/Core Graphics) would take weeks just to match the stroke quality PencilKit gives us for free. Apple's built-in `PKToolPicker` is the fastest path but looks like Notes.app — pro chrome, totally wrong for kids. The chosen hybrid uses `PKCanvasView` for the drawing surface (free pressure, tilt, palm rejection, undo, vector persistence) and wraps it in a custom SwiftUI UI sized for kid hands.

### 3.3 Module boundaries

```
SketchbookApp                  — @main, sets up the root NavigationStack
├── Gallery/
│   ├── GalleryView            — grid of thumbnails, "+" tile, long-press delete
│   ├── GalleryViewModel       — observes DrawingStore
│   └── ThumbnailView          — single tile w/ wiggle + delete bubble
├── Drawing/
│   ├── DrawingView            — full-screen canvas + chrome
│   ├── DrawingViewModel       — owns the active Drawing, save coordination
│   ├── Canvas/
│   │   ├── PencilCanvas       — UIViewRepresentable wrapping PKCanvasView
│   │   └── PhotoLayerView     — backing UIImageView for reference/trace
│   └── Chrome/
│       ├── TopBar             — back, undo/redo, more menu
│       ├── ToolDock           — bottom pill: brushes / colors / photo button
│       ├── BrushPicker        — 4 brushes + eraser, with size bloom
│       ├── ColorPalette       — 10 chunky colors + custom slot, long-press → wheel
│       └── PhotoButton        — opens PhotoFlow sheet
├── Photo/
│   ├── PhotoFlow              — coordinator for source → mode sheets
│   ├── PhotoSourceSheet       — Camera / Photos / Starter
│   ├── PhotoModeSheet         — Look / Trace / Color
│   ├── StarterPhotoLibrary    — bundled assets index
│   └── ColoringPageFilter     — CIPhotoEffectMono → CIEdges → invert pipeline
├── ParentGate/
│   └── ParentGateSheet        — three-dot tap-and-hold-3s
├── Storage/
│   ├── DrawingStore           — ObservableObject, exposes [Drawing], CRUD
│   ├── DrawingRepository      — pure filesystem read/write, no SwiftUI
│   └── ThumbnailRenderer      — composites PKDrawing + photo + bg into PNG
└── Models/
    ├── Drawing                — top-level model
    ├── PhotoLayer             — embedded
    └── KidPalette             — the curated color list
```

Each module has one clear job; the Storage layer never imports SwiftUI; the Drawing module never reads from disk directly.

## 4. Screen-by-screen flow

### 4.1 Gallery (home)

- Scrollable `LazyVGrid` of thumbnails on a soft cream background.
- First tile is always the **"+" New Drawing** tile.
- Tap thumbnail → push `DrawingView` for that drawing.
- Long-press thumbnail → cell wiggles (iOS spring animation), red `×` bubble appears in corner. Tap `×` → opens parent gate → confirms delete.
- No headers, no titles, no nav bar. The app's name is the app icon.

### 4.2 Drawing screen

Landscape-first full-screen layout. Two floating pill bars overlay the canvas:

```
┌─────────────────────────────────────────────────────────┐
│  ⬅                              ↩  ↪              ⋯    │  ← top bar
│                                                         │
│                                                         │
│                   PKCanvasView                          │
│        (photo layer optionally behind it)               │
│                                                         │
│                                                         │
│   ┌───────────────────────────────────────────────┐     │
│   │ 🖊 ✏️ 🖍 🎨 ❌  ●●●●●●●●●● +    📷   │     │  ← tool dock
│   └───────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────┘
```

**Top bar:** ⬅ back (auto-saves, no confirm), ↩ undo, ↪ redo, ⋯ more menu containing:
- **Share** (parent-gated) — export the drawing via the system share sheet.
- **Clear canvas** (parent-gated) — empty the canvas; preserves background colour and photo layer.
- **Background colour** — opens a small popover showing the same 10 muted palette colours plus white; tap to set the canvas background. Persists with the drawing.
- **Let me draw with my finger** — toggle (parent-gated to enable; un-toggling does not require the gate). See §9.

**Tool dock (one continuous pill):**
- *Brush zone* — 4 brushes + eraser. Selected brush is 1.2× and lifted. Tap the already-selected brush → vertical bloom showing 3 sizes (small dot, medium dot, big dot).
- *Color zone* — 10 chunky muted-color circles + 1 "last custom color" slot. Selected color has a thick outline. Long-press any color → presents the full color wheel as a sheet.
- *Photo zone* — single camera-with-plus icon → opens PhotoFlow.

### 4.3 Adaptive UI in practice

- 4-year-old's loop: pick brush, pick color, draw, hit back. Done.
- 10-year-old's discoveries: long-press a brush → sizes; long-press a color → wheel; ⋯ menu → share/clear/background.

## 5. Tool model

### 5.1 Brushes

Each brush maps to a `PKInkingTool` ink type:

| App brush  | PKInkingTool         | Notes                                |
|------------|----------------------|--------------------------------------|
| Pen        | `.pen`               | Firm line, pressure-sensitive width. |
| Crayon     | `.crayon` (iOS 17+)  | Waxy texture; tilt for shading.      |
| Marker     | `.marker`            | Bold, semi-transparent; overlap darkens. |
| Paintbrush | `.watercolor` (iOS 17+) | Soft edges, pressure → width + opacity. |
| Eraser     | `PKEraserTool(.bitmap)` | Pixel eraser by default. Long-press → choice of "erase whole stroke" (`.vector`) vs "erase pixels" (`.bitmap`). |

Size: 3 discrete sizes per brush (small ≈ 4pt, medium ≈ 10pt, big ≈ 22pt). No numeric slider.

### 5.2 Color palette

A curated **muted, less-saturated** palette designed for kids' UI — softer than crayon-box neons:

| Slot | Name           | Approx. hex |
|------|----------------|-------------|
| 1    | Dusty red      | `#C77B7B`   |
| 2    | Warm coral     | `#E0A080`   |
| 3    | Mustard        | `#D4B062`   |
| 4    | Sage green     | `#9CB58F`   |
| 5    | Dusty teal     | `#7AA6A8`   |
| 6    | Soft slate     | `#7E8FAB`   |
| 7    | Lavender       | `#A89AB8`   |
| 8    | Blush pink     | `#E3B8C0`   |
| 9    | Cream          | `#F2E6D0`   |
| 10   | Charcoal       | `#3D3D45`   |
| 11   | (custom slot)  | last picked via color wheel |

Long-press any color → standard `ColorPicker` sheet. Picked color persists in slot 11 until replaced.

### 5.3 Undo/Redo

Backed by `PKCanvasView`'s built-in undo manager (`undoManager`). Chunky arrow buttons in the top bar; both always visible (greyed when unavailable).

## 6. Photo feature

### 6.1 Source sheet

Tap the photo icon → sheet with three big tiles:

| Tile     | Action                                                | Permission           |
|----------|-------------------------------------------------------|----------------------|
| Camera   | `UIImagePickerController` (`.camera`)                 | Parent-gated → camera permission prompt |
| Photos   | `PHPickerViewController`                              | Parent-gated → no permission needed (PHPicker) |
| Starter  | Grid of bundled images (animals, vehicles, faces, shapes) | None |

### 6.2 Mode sheet

After an image is selected, second sheet:

- **Look at it** (`reference`) — Photo pinned to right half (or left for left-handed mode in v2). Non-interactive on canvas.
- **Trace it** (`trace`) — Photo dropped into canvas as background layer at 40% opacity. Temporary opacity slider appears; kid pinches/drags to position. Tap canvas away from photo → confirm.
- **Color it in** (`coloringPage`) — Photo run through Core Image pipeline (CIPhotoEffectMono → CIEdges → CIColorInvert → threshold) to produce black line art on white. Dropped as a locked background.

### 6.3 Photo layer architecture

The photo is **not** part of `PKDrawing`. It's a separate `UIImageView` layered behind the `PKCanvasView`:

- For `reference` mode the photo is rendered in a side panel, outside the canvas's coordinate space.
- For `trace` and `coloringPage`, the photo is a sibling view at z-index below the canvas; the canvas itself remains transparent.
- When saving, `ThumbnailRenderer` composites: background color → photo (if any) → `PKDrawing.image()` → PNG.

A small "remove photo" pill appears in the top bar while a photo is active.

## 7. Data model

```swift
struct Drawing: Identifiable, Codable {
    let id: UUID
    var createdAt: Date
    var updatedAt: Date
    var pkDrawingData: Data           // PKDrawing.dataRepresentation()
    var backgroundColor: ColorRGBA    // canvas background
    var photoLayer: PhotoLayer?
    var thumbnailFilename: String     // "thumb.png" inside the drawing's folder
}

struct PhotoLayer: Codable {
    enum Mode: String, Codable { case reference, trace, coloringPage }
    var imageFilename: String         // "photo.png" inside the drawing's folder
    var mode: Mode
    var opacity: Double               // 0.0…1.0
    var transformMatrix: [CGFloat]    // CGAffineTransform serialised as [a,b,c,d,tx,ty]
}

struct ColorRGBA: Codable { var r, g, b, a: Double }
```

### 7.1 On-disk layout

```
Documents/
└── Drawings/
    └── <uuid>/
        ├── drawing.json   (Drawing as JSON)
        ├── photo.png      (only if photoLayer != nil)
        └── thumb.png
```

### 7.2 Save cadence

- **On every stroke end:** debounce 1s, then persist `pkDrawingData` and regenerate `thumb.png`.
- **On back-button press:** force-flush any pending save synchronously before dismissing.
- **App backgrounded:** force-flush via `scenePhase` observer.

### 7.3 Thumbnail rendering

`ThumbnailRenderer.render(drawing:)` → `UIImage`:
1. Create off-screen `UIGraphicsImageRenderer` at 400×300.
2. Fill with `drawing.backgroundColor`.
3. If `photoLayer != nil`, draw the (transformed) photo.
4. Draw `PKDrawing(data:).image(from: canvasBounds, scale: 1.0)`.
5. PNG-encode, write atomically.

## 8. Parent gate

A modal sheet with three large filled circles arranged horizontally:

```
Grown-up time!
Touch and hold all three dots.

   ⚫    ⚫    ⚫
```

Requirements to pass: all three circles simultaneously receive a touch (`DragGesture(minimumDistance: 0)` per circle) AND that simultaneous state persists for 3.0 seconds. A subtle progress ring around each dot fills as the hold proceeds. Releasing any finger resets all three.

Used for: Camera, Photo Library, Save to Photos, Clear Canvas, Delete Drawing, Toggle finger drawing.

This is the Apple-recommended pattern for kid apps (matches App Store Review Guideline 1.3 expectations).

## 9. Apple Pencil and finger-input

On the wrapped `PKCanvasView`:

```swift
canvas.drawingPolicy = .pencilOnly   // default
canvas.minimumZoomScale = 1.0
canvas.maximumZoomScale = 4.0
canvas.alwaysBounceVertical = false
canvas.alwaysBounceHorizontal = false
canvas.backgroundColor = .clear      // photo layer shows through
```

- Pencil makes marks; fingers do not.
- Fingers pan and pinch-zoom (`PKCanvasView` inherits from `UIScrollView`).
- Palm rejection is automatic with `.pencilOnly`.
- Pressure: each `PKInkingTool` natively uses Pencil pressure.
- Tilt: handled by PencilKit for `.crayon` and `.pencil`.

**Finger-drawing fallback** — single toggle in the ⋯ menu ("Let me draw with my finger"). Parent-gated to *enable* (turning off does not require the gate). Flips `drawingPolicy` to `.anyInput`. Stored globally in `UserDefaults` — it's a "who's using the iPad" preference, not a property of any individual artwork.

## 10. Export

Single "Share" entry in the ⋯ menu → parent gate → render the drawing (`ThumbnailRenderer` at 2048×1536, full quality, no scaling down) → present `UIActivityViewController` with the resulting `UIImage`. The native share sheet covers Save to Photos, AirDrop, Messages, Mail, Print, etc. — we don't build separate buttons for each.

## 11. Testing

### 11.1 Unit tests

- `DrawingRepository`: write + read round-trip; corrupt JSON handling; orphan-file cleanup.
- `ThumbnailRenderer`: produces non-empty PNG; correct dimensions; composites photo behind strokes.
- `ColoringPageFilter`: on a fixture image, produces an image with mean brightness in expected range and detectable edges.
- `KidPalette`: contains exactly 10 colors, all within muted-saturation bounds (HSV S < 0.55, V > 0.4).
- `ParentGateView` logic: three simultaneous touches held 3s passes; one finger lifting resets; <3s release does not pass.

### 11.2 UI tests

- Create → draw a stroke → back → reopen → stroke still there.
- Parent gate: single-finger taps never pass it; verify three simulated touches do.

### 11.3 Manual on-device test plan

Documented as a checklist (committed to repo):
- Pencil pressure produces visibly varied stroke width on Pen.
- Crayon tilt produces shading on iPad Pro with Pencil 2.
- Resting palm during Pencil drawing leaves no marks.
- Pinch-zoom with two fingers while pencil is mid-stroke does not break the stroke.
- Background → foreground → drawing intact and editable.
- Take photo with camera → trace mode → opacity slider responsive → save → thumb shows photo + strokes.

### 11.4 What we won't mock

`PKCanvasView` is too central to the app to mock meaningfully — we test against the real thing in UI tests and on-device manual tests.

## 12. Out of scope for v1

Explicit non-goals, recorded so we don't drift:

- Multi-layer drawings (one drawing layer + optional photo layer is the max)
- Custom brushes beyond PencilKit's built-ins
- Sound effects, haptics, sparkle particles
- iCloud sync / multi-device
- Multi-user, sharing-between-kids, collaboration
- Stickers, stamps, shapes, text tool
- Animation, GIF, video export
- Onboarding flow / tutorial
- Separate Settings screen (only setting lives in ⋯ menu)
- Localization beyond English (no string-heavy UI to translate)
- Left-handed side-by-side reference mode (right-side photo only in v1)

## 13. Open questions / future considerations

These are noted but not blocking v1:

- **iCloud sync.** Filesystem-based persistence makes this a moderate-effort v2 (migrate to `NSUbiquitousContainer` or per-drawing CloudKit records).
- **Custom Metal brushes** (e.g., rainbow stamp brush). Would require a custom drawing layer alongside PencilKit, blended on save.
- **"Photo to coloring page" filter quality.** Core Image edges work fine for high-contrast photos; busy backgrounds may produce noisy results. May want to add a "smoothness" pre-pass (CIGaussianBlur) and expose it to the kid as a "make it simpler" slider.
- **Left-handed mode.** Detect dominant hand from where the kid touches first, mirror the reference panel side.
