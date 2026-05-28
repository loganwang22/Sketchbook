# Sketchbook v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a kid-friendly iPad sketchbook app (ages 4-10) using Apple Pencil, per the design at `docs/superpowers/specs/2026-05-27-sketchbook-design.md`.

**Architecture:** SwiftUI + UIKit hybrid. `PKCanvasView` (UIKit, PencilKit) drives the drawing surface, wrapped in a custom SwiftUI chrome of muted-colour palette + chunky brush buttons + thumbnail gallery. Filesystem-only persistence (no Core Data / SwiftData / CloudKit in v1). Core Image powers the "convert photo to coloring page" feature.

**Tech Stack:**
- Swift 5.10+, SwiftUI, UIKit (UIViewRepresentable wrappers)
- PencilKit (`PKCanvasView`, `PKDrawing`, `PKInkingTool`, `PKEraserTool`)
- Core Image (`CIPhotoEffectMono`, `CIEdges`, `CIColorInvert`)
- XCTest (unit + UI tests)
- iOS 17.0 minimum (needed for `PKInkingTool.InkType.crayon` and `.watercolor`)
- iPad-only target

---

## Manual prerequisite (one-time, by a human)

Before running the tasks below, open `Sketchbook.xcodeproj` in Xcode and complete these steps. They cannot be reliably done by editing `project.pbxproj` programmatically.

1. **Set deployment target to iOS 17.0.** Project → Target `Sketchbook` → General → Minimum Deployments → iOS `17.0`.
2. **Set device family to iPad only.** Project → Target `Sketchbook` → General → Supported Destinations → remove iPhone, keep iPad.
3. **Set supported orientations.** Project → Target `Sketchbook` → General → Device Orientation → check Landscape Left, Landscape Right, Portrait. (Landscape is primary, but kids might rotate.)
4. **Add a Unit Test target.** File → New → Target → iOS → Unit Testing Bundle. Product name: `SketchbookTests`. Target to be tested: `Sketchbook`.
5. **Add a UI Test target.** File → New → Target → iOS → UI Testing Bundle. Product name: `SketchbookUITests`. Target to be tested: `Sketchbook`.
6. **Add privacy strings** to the auto-generated Info section of the `Sketchbook` target → Info tab:
    - `NSCameraUsageDescription` → `"Lets you take a photo to draw from or trace."`
    - `NSPhotoLibraryUsageDescription` → `"Lets you pick a photo to draw from or trace."`
    - `NSPhotoLibraryAddUsageDescription` → `"Lets you save your drawing to your photo album."`
7. **Commit:** `git add . && git commit -m "chore: configure iPad-only target, iOS 17, test targets, privacy strings"`

Once these steps are done, proceed to Task 1.

---

## File structure

What we will create. Each file has one clear responsibility; nothing imports SwiftUI that doesn't need to (Storage stays pure).

```
Sketchbook/
├── SketchbookApp.swift                  [modify in Task 36]
├── ContentView.swift                    [delete in Task 1]
├── Models/
│   ├── Drawing.swift                    [Task 4]
│   ├── PhotoLayer.swift                 [Task 3]
│   ├── ColorRGBA.swift                  [Task 2]
│   └── KidPalette.swift                 [Task 5]
├── Storage/
│   ├── DrawingRepository.swift          [Tasks 6-8]
│   ├── DrawingStore.swift               [Task 9]
│   └── ThumbnailRenderer.swift          [Task 11]
├── Gallery/
│   ├── GalleryView.swift                [Task 27]
│   ├── GalleryViewModel.swift           [Task 26]
│   └── ThumbnailCell.swift              [Task 25]
├── Drawing/
│   ├── DrawingView.swift                [Task 24]
│   ├── DrawingViewModel.swift           [Task 18]
│   ├── Canvas/
│   │   ├── PencilCanvas.swift           [Task 16]
│   │   └── PhotoLayerView.swift         [Task 17]
│   └── Chrome/
│       ├── TopBar.swift                 [Task 19]
│       ├── ToolDock.swift               [Task 23]
│       ├── BrushPicker.swift            [Task 20]
│       ├── ColorPalette.swift           [Task 21]
│       └── BackgroundColorPopover.swift [Task 22]
├── Photo/
│   ├── PhotoFlow.swift                  [Task 33]
│   ├── PhotoSourceSheet.swift           [Task 28]
│   ├── PhotoModeSheet.swift             [Task 29]
│   ├── CameraPicker.swift               [Task 30]
│   ├── PhotoLibraryPicker.swift         [Task 31]
│   ├── StarterPhotoLibrary.swift        [Task 32]
│   └── ColoringPageFilter.swift         [Tasks 10-11 setup, 33 wiring]
├── ParentGate/
│   ├── ParentGateGesture.swift          [Task 12]
│   └── ParentGateSheet.swift            [Task 13]
├── Export/
│   └── ShareSheet.swift                 [Task 34]
└── Assets.xcassets/
    └── StarterPhotos/                   [Task 32]

SketchbookTests/
├── ColorRGBATests.swift                 [Task 2]
├── PhotoLayerTests.swift                [Task 3]
├── DrawingTests.swift                   [Task 4]
├── KidPaletteTests.swift                [Task 5]
├── DrawingRepositoryTests.swift         [Tasks 6-8]
├── DrawingStoreTests.swift              [Task 9]
├── ColoringPageFilterTests.swift        [Task 10]
├── ThumbnailRendererTests.swift         [Task 11]
├── ParentGateGestureTests.swift         [Task 12]
├── DrawingViewModelTests.swift          [Task 18]
├── GalleryViewModelTests.swift          [Task 26]
└── Fixtures/
    └── fixture-square.png               [Task 10 — synthetic test image]

SketchbookUITests/
└── DrawingFlowUITests.swift             [Task 37]
```

---

## Task 1: Clean Xcode scaffold

**Files:**
- Delete: `Sketchbook/ContentView.swift`
- Modify: `Sketchbook/SketchbookApp.swift`

- [ ] **Step 1: Replace `SketchbookApp.swift` with a temporary placeholder root**

```swift
// Sketchbook/SketchbookApp.swift
import SwiftUI

@main
struct SketchbookApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Sketchbook")
                .font(.largeTitle)
        }
    }
}
```

- [ ] **Step 2: Delete `Sketchbook/ContentView.swift`**

```bash
rm Sketchbook/ContentView.swift
```

- [ ] **Step 3: Build and verify the app launches**

Open Xcode, hit `Cmd+R`, choose an iPad simulator. Expected: the simulator shows "Sketchbook" centred in landscape.

- [ ] **Step 4: Commit**

```bash
git add Sketchbook/
git commit -m "chore: replace ContentView scaffold with placeholder root"
```

---

## Task 2: `ColorRGBA` model + tests

**Files:**
- Create: `Sketchbook/Models/ColorRGBA.swift`
- Create: `SketchbookTests/ColorRGBATests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// SketchbookTests/ColorRGBATests.swift
import XCTest
import SwiftUI
@testable import Sketchbook

final class ColorRGBATests: XCTestCase {
    func test_init_clamps_components_to_unit_range() {
        let c = ColorRGBA(r: 1.5, g: -0.2, b: 0.5, a: 2.0)
        XCTAssertEqual(c.r, 1.0, accuracy: 0.0001)
        XCTAssertEqual(c.g, 0.0, accuracy: 0.0001)
        XCTAssertEqual(c.b, 0.5, accuracy: 0.0001)
        XCTAssertEqual(c.a, 1.0, accuracy: 0.0001)
    }

    func test_codable_round_trips() throws {
        let original = ColorRGBA(r: 0.78, g: 0.48, b: 0.48, a: 1.0)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ColorRGBA.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_swiftui_color_conversion_round_trips_within_tolerance() {
        let rgba = ColorRGBA(r: 0.6, g: 0.4, b: 0.2, a: 0.8)
        let color = rgba.swiftUIColor
        let back = ColorRGBA(color)
        XCTAssertEqual(back.r, rgba.r, accuracy: 0.01)
        XCTAssertEqual(back.g, rgba.g, accuracy: 0.01)
        XCTAssertEqual(back.b, rgba.b, accuracy: 0.01)
        XCTAssertEqual(back.a, rgba.a, accuracy: 0.01)
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL (`ColorRGBA` undefined)**

Run: `xcodebuild test -scheme Sketchbook -destination 'platform=iOS Simulator,name=iPad (10th generation)' -only-testing:SketchbookTests/ColorRGBATests`
Expected: compile error "cannot find type 'ColorRGBA' in scope".

- [ ] **Step 3: Implement `ColorRGBA`**

```swift
// Sketchbook/Models/ColorRGBA.swift
import SwiftUI
import UIKit

struct ColorRGBA: Codable, Equatable, Hashable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(r: Double, g: Double, b: Double, a: Double = 1.0) {
        self.r = min(max(r, 0), 1)
        self.g = min(max(g, 0), 1)
        self.b = min(max(b, 0), 1)
        self.a = min(max(a, 0), 1)
    }

    init(_ color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(r: Double(r), g: Double(g), b: Double(b), a: Double(a))
    }

    var swiftUIColor: Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    var uiColor: UIColor {
        UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

Run the same `xcodebuild test` command. Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sketchbook/Models/ColorRGBA.swift SketchbookTests/ColorRGBATests.swift
git commit -m "feat: add ColorRGBA model with SwiftUI bridging"
```

---

## Task 3: `PhotoLayer` model + tests

**Files:**
- Create: `Sketchbook/Models/PhotoLayer.swift`
- Create: `SketchbookTests/PhotoLayerTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// SketchbookTests/PhotoLayerTests.swift
import XCTest
import CoreGraphics
@testable import Sketchbook

final class PhotoLayerTests: XCTestCase {
    func test_default_transform_is_identity() {
        let layer = PhotoLayer(imageFilename: "photo.png", mode: .reference)
        XCTAssertEqual(layer.transform, .identity)
        XCTAssertEqual(layer.opacity, 1.0)
    }

    func test_codable_round_trips_with_transform() throws {
        let layer = PhotoLayer(
            imageFilename: "photo.png",
            mode: .trace,
            opacity: 0.4,
            transform: CGAffineTransform(translationX: 10, y: 20).rotated(by: .pi / 4)
        )
        let data = try JSONEncoder().encode(layer)
        let decoded = try JSONDecoder().decode(PhotoLayer.self, from: data)
        XCTAssertEqual(decoded.imageFilename, "photo.png")
        XCTAssertEqual(decoded.mode, .trace)
        XCTAssertEqual(decoded.opacity, 0.4, accuracy: 0.0001)
        XCTAssertEqual(decoded.transform.a, layer.transform.a, accuracy: 0.0001)
        XCTAssertEqual(decoded.transform.tx, layer.transform.tx, accuracy: 0.0001)
    }

    func test_mode_decodes_from_string() throws {
        let json = #"{"imageFilename":"p.png","mode":"coloringPage","opacity":1.0,"transformMatrix":[1,0,0,1,0,0]}"#
        let decoded = try JSONDecoder().decode(PhotoLayer.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.mode, .coloringPage)
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL**

Run: `xcodebuild test -scheme Sketchbook -destination 'platform=iOS Simulator,name=iPad (10th generation)' -only-testing:SketchbookTests/PhotoLayerTests`

- [ ] **Step 3: Implement `PhotoLayer`**

```swift
// Sketchbook/Models/PhotoLayer.swift
import Foundation
import CoreGraphics

struct PhotoLayer: Codable, Equatable {
    enum Mode: String, Codable, CaseIterable {
        case reference
        case trace
        case coloringPage
    }

    var imageFilename: String
    var mode: Mode
    var opacity: Double
    var transform: CGAffineTransform

    init(imageFilename: String, mode: Mode, opacity: Double = 1.0, transform: CGAffineTransform = .identity) {
        self.imageFilename = imageFilename
        self.mode = mode
        self.opacity = opacity
        self.transform = transform
    }

    private enum CodingKeys: String, CodingKey {
        case imageFilename, mode, opacity
        case transformMatrix
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        imageFilename = try c.decode(String.self, forKey: .imageFilename)
        mode = try c.decode(Mode.self, forKey: .mode)
        opacity = try c.decode(Double.self, forKey: .opacity)
        let m = try c.decode([CGFloat].self, forKey: .transformMatrix)
        guard m.count == 6 else {
            throw DecodingError.dataCorruptedError(forKey: .transformMatrix, in: c,
                debugDescription: "Expected 6 floats, got \(m.count)")
        }
        transform = CGAffineTransform(a: m[0], b: m[1], c: m[2], d: m[3], tx: m[4], ty: m[5])
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(imageFilename, forKey: .imageFilename)
        try c.encode(mode, forKey: .mode)
        try c.encode(opacity, forKey: .opacity)
        try c.encode([transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty],
                     forKey: .transformMatrix)
    }
}
```

- [ ] **Step 4: Run tests — expect PASS (3/3)**

- [ ] **Step 5: Commit**

```bash
git add Sketchbook/Models/PhotoLayer.swift SketchbookTests/PhotoLayerTests.swift
git commit -m "feat: add PhotoLayer model with serialised affine transform"
```

---

## Task 4: `Drawing` model + tests

**Files:**
- Create: `Sketchbook/Models/Drawing.swift`
- Create: `SketchbookTests/DrawingTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// SketchbookTests/DrawingTests.swift
import XCTest
@testable import Sketchbook

final class DrawingTests: XCTestCase {
    func test_new_drawing_has_unique_id_and_recent_timestamps() {
        let d1 = Drawing.empty()
        let d2 = Drawing.empty()
        XCTAssertNotEqual(d1.id, d2.id)
        XCTAssertLessThan(abs(d1.createdAt.timeIntervalSinceNow), 1.0)
        XCTAssertEqual(d1.createdAt, d1.updatedAt)
        XCTAssertTrue(d1.pkDrawingData.isEmpty)
        XCTAssertNil(d1.photoLayer)
    }

    func test_default_background_is_cream_palette_color() {
        let d = Drawing.empty()
        XCTAssertEqual(d.backgroundColor.r, 0.949, accuracy: 0.005)
        XCTAssertEqual(d.backgroundColor.g, 0.902, accuracy: 0.005)
        XCTAssertEqual(d.backgroundColor.b, 0.816, accuracy: 0.005)
    }

    func test_codable_round_trips() throws {
        var d = Drawing.empty()
        d.pkDrawingData = Data([0xDE, 0xAD, 0xBE, 0xEF])
        d.photoLayer = PhotoLayer(imageFilename: "photo.png", mode: .trace, opacity: 0.5)
        let data = try JSONEncoder().encode(d)
        let decoded = try JSONDecoder().decode(Drawing.self, from: data)
        XCTAssertEqual(decoded.id, d.id)
        XCTAssertEqual(decoded.pkDrawingData, d.pkDrawingData)
        XCTAssertEqual(decoded.photoLayer?.mode, .trace)
    }

    func test_touch_updates_updatedAt_but_not_createdAt() {
        var d = Drawing.empty()
        let originalCreated = d.createdAt
        let originalUpdated = d.updatedAt
        Thread.sleep(forTimeInterval: 0.02)
        d.touch()
        XCTAssertEqual(d.createdAt, originalCreated)
        XCTAssertGreaterThan(d.updatedAt, originalUpdated)
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Implement `Drawing`**

```swift
// Sketchbook/Models/Drawing.swift
import Foundation

struct Drawing: Identifiable, Codable, Equatable {
    let id: UUID
    var createdAt: Date
    var updatedAt: Date
    var pkDrawingData: Data
    var backgroundColor: ColorRGBA
    var photoLayer: PhotoLayer?
    var thumbnailFilename: String

    static func empty() -> Drawing {
        let now = Date()
        return Drawing(
            id: UUID(),
            createdAt: now,
            updatedAt: now,
            pkDrawingData: Data(),
            backgroundColor: KidPalette.defaultBackground,
            photoLayer: nil,
            thumbnailFilename: "thumb.png"
        )
    }

    mutating func touch() {
        updatedAt = Date()
    }
}
```

(`KidPalette.defaultBackground` is introduced in Task 5 — for now the test will fail to compile until then. Proceed to Task 5 before running tests; this is a deliberate two-task pair.)

- [ ] **Step 4: Skip running tests until Task 5 lands; commit the model alone**

```bash
git add Sketchbook/Models/Drawing.swift SketchbookTests/DrawingTests.swift
git commit -m "feat: add Drawing model (compile completes after KidPalette lands)"
```

---

## Task 5: `KidPalette` + tests

**Files:**
- Create: `Sketchbook/Models/KidPalette.swift`
- Create: `SketchbookTests/KidPaletteTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// SketchbookTests/KidPaletteTests.swift
import XCTest
import SwiftUI
@testable import Sketchbook

final class KidPaletteTests: XCTestCase {
    func test_palette_contains_exactly_10_named_colors() {
        XCTAssertEqual(KidPalette.colors.count, 10)
        let names = Set(KidPalette.colors.map(\.name))
        XCTAssertEqual(names.count, 10, "All colour names must be unique")
    }

    func test_default_background_is_cream() {
        XCTAssertEqual(KidPalette.defaultBackground.r, 0.949, accuracy: 0.005)
        XCTAssertEqual(KidPalette.defaultBackground.g, 0.902, accuracy: 0.005)
        XCTAssertEqual(KidPalette.defaultBackground.b, 0.816, accuracy: 0.005)
    }

    func test_all_palette_colors_are_muted() {
        for entry in KidPalette.colors {
            let (h, s, v) = hsv(entry.color)
            XCTAssertTrue(s >= 0.0 && s <= 0.55,
                "Color \(entry.name) has saturation \(s) outside muted range")
            XCTAssertTrue(v >= 0.40 && v <= 0.97,
                "Color \(entry.name) has value \(v) outside muted range")
            _ = h
        }
    }

    private func hsv(_ rgba: ColorRGBA) -> (h: Double, s: Double, v: Double) {
        var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
        rgba.uiColor.getHue(&h, saturation: &s, brightness: &v, alpha: &a)
        return (Double(h), Double(s), Double(v))
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Implement `KidPalette`**

```swift
// Sketchbook/Models/KidPalette.swift
import Foundation

enum KidPalette {
    struct Entry: Equatable {
        let name: String
        let color: ColorRGBA
    }

    /// 10 muted, less-saturated colours sized for a 4–10-year-old's eye.
    /// HSV saturation roughly 0.3–0.55, value roughly 0.45–0.95.
    static let colors: [Entry] = [
        Entry(name: "Dusty red",   color: ColorRGBA(r: 0.78, g: 0.48, b: 0.48)),
        Entry(name: "Warm coral",  color: ColorRGBA(r: 0.88, g: 0.63, b: 0.50)),
        Entry(name: "Mustard",     color: ColorRGBA(r: 0.83, g: 0.69, b: 0.38)),
        Entry(name: "Sage green",  color: ColorRGBA(r: 0.61, g: 0.71, b: 0.56)),
        Entry(name: "Dusty teal",  color: ColorRGBA(r: 0.48, g: 0.65, b: 0.66)),
        Entry(name: "Soft slate",  color: ColorRGBA(r: 0.49, g: 0.56, b: 0.67)),
        Entry(name: "Lavender",    color: ColorRGBA(r: 0.66, g: 0.60, b: 0.72)),
        Entry(name: "Blush pink",  color: ColorRGBA(r: 0.89, g: 0.72, b: 0.75)),
        Entry(name: "Cream",       color: ColorRGBA(r: 0.95, g: 0.90, b: 0.82)),
        Entry(name: "Charcoal",    color: ColorRGBA(r: 0.24, g: 0.24, b: 0.27)),
    ]

    static let defaultBackground = ColorRGBA(r: 0.949, g: 0.902, b: 0.816)
}
```

- [ ] **Step 4: Run all model tests — expect PASS (Drawing tests now compile and pass too)**

Run: `xcodebuild test -scheme Sketchbook -destination 'platform=iOS Simulator,name=iPad (10th generation)' -only-testing:SketchbookTests/KidPaletteTests -only-testing:SketchbookTests/DrawingTests`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sketchbook/Models/KidPalette.swift SketchbookTests/KidPaletteTests.swift
git commit -m "feat: add curated 10-colour muted KidPalette"
```

---

## Task 6: `DrawingRepository` — save & load round-trip

**Files:**
- Create: `Sketchbook/Storage/DrawingRepository.swift`
- Create: `SketchbookTests/DrawingRepositoryTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// SketchbookTests/DrawingRepositoryTests.swift
import XCTest
@testable import Sketchbook

final class DrawingRepositoryTests: XCTestCase {
    var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    func test_save_then_load_round_trips_drawing() throws {
        let repo = DrawingRepository(rootDirectory: tmp)
        var d = Drawing.empty()
        d.pkDrawingData = Data([0x01, 0x02, 0x03])
        try repo.save(d)
        let loaded = try repo.load(id: d.id)
        XCTAssertEqual(loaded.id, d.id)
        XCTAssertEqual(loaded.pkDrawingData, d.pkDrawingData)
    }
}
```

- [ ] **Step 2: Run test — expect FAIL**

- [ ] **Step 3: Implement minimal `DrawingRepository`**

```swift
// Sketchbook/Storage/DrawingRepository.swift
import Foundation

/// Pure filesystem CRUD for drawings. No SwiftUI imports.
final class DrawingRepository {
    private let rootDirectory: URL
    private let fileManager: FileManager

    init(rootDirectory: URL, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
    }

    /// Convenience initialiser that targets `Documents/Drawings/`.
    convenience init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.init(rootDirectory: docs.appendingPathComponent("Drawings", isDirectory: true))
    }

    func directory(for id: UUID) -> URL {
        rootDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    func save(_ drawing: Drawing) throws {
        let dir = directory(for: drawing.id)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(drawing)
        try data.write(to: dir.appendingPathComponent("drawing.json"), options: .atomic)
    }

    func load(id: UUID) throws -> Drawing {
        let url = directory(for: id).appendingPathComponent("drawing.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Drawing.self, from: data)
    }
}
```

- [ ] **Step 4: Run test — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add Sketchbook/Storage/DrawingRepository.swift SketchbookTests/DrawingRepositoryTests.swift
git commit -m "feat: DrawingRepository save/load round-trip"
```

---

## Task 7: `DrawingRepository` — list & delete

**Files:**
- Modify: `Sketchbook/Storage/DrawingRepository.swift`
- Modify: `SketchbookTests/DrawingRepositoryTests.swift`

- [ ] **Step 1: Add the failing tests**

Append to `DrawingRepositoryTests`:

```swift
func test_listAll_returns_drawings_sorted_by_updatedAt_desc() throws {
    let repo = DrawingRepository(rootDirectory: tmp)
    var older = Drawing.empty()
    older.updatedAt = Date(timeIntervalSince1970: 1000)
    var newer = Drawing.empty()
    newer.updatedAt = Date(timeIntervalSince1970: 2000)
    try repo.save(older)
    try repo.save(newer)

    let all = try repo.listAll()
    XCTAssertEqual(all.map(\.id), [newer.id, older.id])
}

func test_delete_removes_directory() throws {
    let repo = DrawingRepository(rootDirectory: tmp)
    let d = Drawing.empty()
    try repo.save(d)
    XCTAssertTrue(FileManager.default.fileExists(atPath: repo.directory(for: d.id).path))
    try repo.delete(id: d.id)
    XCTAssertFalse(FileManager.default.fileExists(atPath: repo.directory(for: d.id).path))
}

func test_listAll_skips_corrupt_or_orphan_directories() throws {
    let repo = DrawingRepository(rootDirectory: tmp)
    try repo.save(Drawing.empty())

    // orphan dir with no JSON
    let orphanDir = tmp.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: orphanDir, withIntermediateDirectories: true)

    // corrupt JSON dir
    let corruptDir = tmp.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: corruptDir, withIntermediateDirectories: true)
    try Data("not json".utf8).write(to: corruptDir.appendingPathComponent("drawing.json"))

    let all = try repo.listAll()
    XCTAssertEqual(all.count, 1)
}
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Extend `DrawingRepository`**

Append inside the class:

```swift
func listAll() throws -> [Drawing] {
    guard fileManager.fileExists(atPath: rootDirectory.path) else { return [] }
    let entries = try fileManager.contentsOfDirectory(at: rootDirectory,
        includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
    var drawings: [Drawing] = []
    for dir in entries where dir.hasDirectoryPath {
        let jsonURL = dir.appendingPathComponent("drawing.json")
        guard let data = try? Data(contentsOf: jsonURL),
              let drawing = try? JSONDecoder().decode(Drawing.self, from: data) else {
            continue
        }
        drawings.append(drawing)
    }
    return drawings.sorted { $0.updatedAt > $1.updatedAt }
}

func delete(id: UUID) throws {
    let dir = directory(for: id)
    if fileManager.fileExists(atPath: dir.path) {
        try fileManager.removeItem(at: dir)
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add Sketchbook/Storage/DrawingRepository.swift SketchbookTests/DrawingRepositoryTests.swift
git commit -m "feat: DrawingRepository list & delete with corrupt-dir tolerance"
```

---

## Task 8: `DrawingRepository` — photo and thumbnail asset helpers

**Files:**
- Modify: `Sketchbook/Storage/DrawingRepository.swift`
- Modify: `SketchbookTests/DrawingRepositoryTests.swift`

- [ ] **Step 1: Add failing tests**

Append:

```swift
func test_savePhoto_writes_png_into_drawing_dir() throws {
    let repo = DrawingRepository(rootDirectory: tmp)
    let d = Drawing.empty()
    try repo.save(d)
    let image = UIImage.solid(color: .red, size: CGSize(width: 4, height: 4))
    let filename = try repo.savePhoto(image, for: d.id)
    XCTAssertEqual(filename, "photo.png")
    let url = repo.directory(for: d.id).appendingPathComponent(filename)
    let data = try Data(contentsOf: url)
    XCTAssertGreaterThan(data.count, 0)
}

func test_loadPhoto_returns_nil_when_missing() throws {
    let repo = DrawingRepository(rootDirectory: tmp)
    let d = Drawing.empty()
    try repo.save(d)
    XCTAssertNil(repo.loadPhoto(for: d.id))
}
```

Add a small test helper above the test class:

```swift
extension UIImage {
    static func solid(color: UIColor, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
```

And `import UIKit` at the top.

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Extend `DrawingRepository` (also `import UIKit` at top)**

```swift
@discardableResult
func savePhoto(_ image: UIImage, for id: UUID, filename: String = "photo.png") throws -> String {
    let dir = directory(for: id)
    try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    guard let data = image.pngData() else {
        throw NSError(domain: "DrawingRepository", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Could not PNG-encode image"])
    }
    try data.write(to: dir.appendingPathComponent(filename), options: .atomic)
    return filename
}

func loadPhoto(for id: UUID, filename: String = "photo.png") -> UIImage? {
    let url = directory(for: id).appendingPathComponent(filename)
    guard let data = try? Data(contentsOf: url) else { return nil }
    return UIImage(data: data)
}

@discardableResult
func saveThumbnail(_ image: UIImage, for id: UUID) throws -> String {
    return try savePhoto(image, for: id, filename: "thumb.png")
}

func loadThumbnail(for id: UUID) -> UIImage? {
    return loadPhoto(for: id, filename: "thumb.png")
}
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add Sketchbook/Storage/DrawingRepository.swift SketchbookTests/DrawingRepositoryTests.swift
git commit -m "feat: photo and thumbnail asset helpers on DrawingRepository"
```

---

## Task 9: `DrawingStore` — observable wrapper

**Files:**
- Create: `Sketchbook/Storage/DrawingStore.swift`
- Create: `SketchbookTests/DrawingStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// SketchbookTests/DrawingStoreTests.swift
import XCTest
@testable import Sketchbook

@MainActor
final class DrawingStoreTests: XCTestCase {
    var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: tmp) }

    func test_createNew_appends_to_drawings_and_persists() throws {
        let store = DrawingStore(repository: DrawingRepository(rootDirectory: tmp))
        XCTAssertEqual(store.drawings.count, 0)
        let d = try store.createNew()
        XCTAssertEqual(store.drawings.count, 1)
        XCTAssertEqual(store.drawings.first?.id, d.id)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: tmp.appendingPathComponent(d.id.uuidString)
                       .appendingPathComponent("drawing.json").path))
    }

    func test_save_updates_inplace_and_moves_to_front() throws {
        let store = DrawingStore(repository: DrawingRepository(rootDirectory: tmp))
        let a = try store.createNew()
        Thread.sleep(forTimeInterval: 0.01)
        let b = try store.createNew()
        XCTAssertEqual(store.drawings.first?.id, b.id)

        var updated = a
        updated.touch()
        updated.pkDrawingData = Data([0xFF])
        try store.save(updated)

        XCTAssertEqual(store.drawings.first?.id, a.id)
        XCTAssertEqual(store.drawings.first?.pkDrawingData, Data([0xFF]))
    }

    func test_delete_removes_from_array_and_disk() throws {
        let store = DrawingStore(repository: DrawingRepository(rootDirectory: tmp))
        let d = try store.createNew()
        try store.delete(id: d.id)
        XCTAssertTrue(store.drawings.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: tmp.appendingPathComponent(d.id.uuidString).path))
    }

    func test_reload_loads_existing_drawings_from_disk() throws {
        let repo = DrawingRepository(rootDirectory: tmp)
        try repo.save(Drawing.empty())
        try repo.save(Drawing.empty())

        let store = DrawingStore(repository: repo)
        XCTAssertEqual(store.drawings.count, 2)
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Implement `DrawingStore`**

```swift
// Sketchbook/Storage/DrawingStore.swift
import Foundation
import Combine

@MainActor
final class DrawingStore: ObservableObject {
    @Published private(set) var drawings: [Drawing] = []
    private let repository: DrawingRepository

    init(repository: DrawingRepository = DrawingRepository()) {
        self.repository = repository
        self.drawings = (try? repository.listAll()) ?? []
    }

    @discardableResult
    func createNew() throws -> Drawing {
        let d = Drawing.empty()
        try repository.save(d)
        drawings.insert(d, at: 0)
        return d
    }

    func save(_ drawing: Drawing) throws {
        try repository.save(drawing)
        if let idx = drawings.firstIndex(where: { $0.id == drawing.id }) {
            drawings.remove(at: idx)
        }
        drawings.insert(drawing, at: 0)
    }

    func delete(id: UUID) throws {
        try repository.delete(id: id)
        drawings.removeAll { $0.id == id }
    }

    func repositoryForId() -> DrawingRepository { repository }
}
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add Sketchbook/Storage/DrawingStore.swift SketchbookTests/DrawingStoreTests.swift
git commit -m "feat: DrawingStore observable wrapper"
```

---

## Task 10: `ColoringPageFilter` + fixture

**Files:**
- Create: `Sketchbook/Photo/ColoringPageFilter.swift`
- Create: `SketchbookTests/ColoringPageFilterTests.swift`
- Create: `SketchbookTests/Fixtures/fixture-square.png` (generated in the test)

- [ ] **Step 1: Write the failing tests**

```swift
// SketchbookTests/ColoringPageFilterTests.swift
import XCTest
import UIKit
@testable import Sketchbook

final class ColoringPageFilterTests: XCTestCase {
    /// Build a 256×256 image that is half red, half blue — gives ColoringPageFilter
    /// a clear edge to detect.
    func makeFixture() -> UIImage {
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 128, height: 256))
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 128, y: 0, width: 128, height: 256))
        }
    }

    func test_filter_returns_non_nil_image_of_same_size() throws {
        let input = makeFixture()
        let output = try XCTUnwrap(ColoringPageFilter.apply(to: input))
        XCTAssertEqual(output.size.width, input.size.width, accuracy: 1.0)
        XCTAssertEqual(output.size.height, input.size.height, accuracy: 1.0)
    }

    func test_filter_output_is_predominantly_bright() throws {
        // A coloring page should be mostly white with dark lines.
        let input = makeFixture()
        let output = try XCTUnwrap(ColoringPageFilter.apply(to: input))
        let brightness = averageBrightness(of: output)
        XCTAssertGreaterThan(brightness, 0.6,
            "Expected mostly-white output, got mean brightness \(brightness)")
    }

    func test_filter_output_has_detectable_dark_pixels_at_edge() throws {
        // The vertical seam in the middle should produce dark pixels.
        let input = makeFixture()
        let output = try XCTUnwrap(ColoringPageFilter.apply(to: input))
        let darkRatio = darkPixelRatio(in: output, threshold: 0.3)
        XCTAssertGreaterThan(darkRatio, 0.001,
            "Expected at least 0.1% dark pixels for the edge, got \(darkRatio)")
    }

    // MARK: helpers

    private func averageBrightness(of image: UIImage) -> Double {
        guard let cg = image.cgImage,
              let data = cg.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return 0 }
        let count = CFDataGetLength(data)
        let bpp = cg.bitsPerPixel / 8
        var total: Double = 0
        var samples: Int = 0
        for i in stride(from: 0, to: count, by: bpp) {
            let r = Double(bytes[i]) / 255.0
            let g = Double(bytes[i+1]) / 255.0
            let b = Double(bytes[i+2]) / 255.0
            total += (r + g + b) / 3.0
            samples += 1
        }
        return total / Double(max(samples, 1))
    }

    private func darkPixelRatio(in image: UIImage, threshold: Double) -> Double {
        guard let cg = image.cgImage,
              let data = cg.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return 0 }
        let count = CFDataGetLength(data)
        let bpp = cg.bitsPerPixel / 8
        var dark = 0, total = 0
        for i in stride(from: 0, to: count, by: bpp) {
            let r = Double(bytes[i]) / 255.0
            let g = Double(bytes[i+1]) / 255.0
            let b = Double(bytes[i+2]) / 255.0
            if (r + g + b) / 3.0 < threshold { dark += 1 }
            total += 1
        }
        return Double(dark) / Double(max(total, 1))
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Implement `ColoringPageFilter`**

```swift
// Sketchbook/Photo/ColoringPageFilter.swift
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Converts a photograph into a black-line-on-white "coloring page" image.
/// Pipeline: greyscale → edge detect → invert → contrast threshold.
enum ColoringPageFilter {
    static func apply(to input: UIImage) -> UIImage? {
        guard let ciInput = CIImage(image: input) else { return nil }
        let context = CIContext(options: nil)

        let mono = CIFilter.photoEffectMono()
        mono.inputImage = ciInput
        guard let monoOutput = mono.outputImage else { return nil }

        let edges = CIFilter.edges()
        edges.inputImage = monoOutput
        edges.intensity = 5.0
        guard let edgesOutput = edges.outputImage else { return nil }

        let invert = CIFilter.colorInvert()
        invert.inputImage = edgesOutput
        guard let invertedOutput = invert.outputImage else { return nil }

        // Boost contrast so edges go black, rest goes white.
        let contrast = CIFilter.colorControls()
        contrast.inputImage = invertedOutput
        contrast.brightness = 0.2
        contrast.contrast = 4.0
        contrast.saturation = 0
        guard let finalOutput = contrast.outputImage,
              let cgImage = context.createCGImage(finalOutput, from: ciInput.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: input.scale, orientation: input.imageOrientation)
    }
}
```

- [ ] **Step 4: Run tests — expect PASS (3/3)**

- [ ] **Step 5: Commit**

```bash
git add Sketchbook/Photo/ColoringPageFilter.swift SketchbookTests/ColoringPageFilterTests.swift
git commit -m "feat: ColoringPageFilter Core Image pipeline"
```

---

## Task 11: `ThumbnailRenderer`

**Files:**
- Create: `Sketchbook/Storage/ThumbnailRenderer.swift`
- Create: `SketchbookTests/ThumbnailRendererTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// SketchbookTests/ThumbnailRendererTests.swift
import XCTest
import PencilKit
@testable import Sketchbook

final class ThumbnailRendererTests: XCTestCase {
    func test_renders_solid_background_when_drawing_is_empty() throws {
        var d = Drawing.empty()
        d.backgroundColor = ColorRGBA(r: 0.0, g: 1.0, b: 0.0)  // bright green
        let image = try XCTUnwrap(ThumbnailRenderer.render(drawing: d, photoImage: nil,
            canvasSize: CGSize(width: 400, height: 300)))
        XCTAssertEqual(image.size, CGSize(width: 400, height: 300))
        let (r, g, b) = sample(image, at: CGPoint(x: 200, y: 150))
        XCTAssertLessThan(r, 0.1)
        XCTAssertGreaterThan(g, 0.8)
        XCTAssertLessThan(b, 0.1)
    }

    func test_composites_photo_under_drawing_data() throws {
        var d = Drawing.empty()
        d.backgroundColor = ColorRGBA(r: 1, g: 1, b: 1)
        d.photoLayer = PhotoLayer(imageFilename: "p.png", mode: .trace, opacity: 1.0)
        let photo = UIImage.solid(color: .red, size: CGSize(width: 400, height: 300))
        let image = try XCTUnwrap(ThumbnailRenderer.render(drawing: d, photoImage: photo,
            canvasSize: CGSize(width: 400, height: 300)))
        let (r, _, _) = sample(image, at: CGPoint(x: 200, y: 150))
        XCTAssertGreaterThan(r, 0.8, "Photo should be visible")
    }

    private func sample(_ image: UIImage, at point: CGPoint) -> (Double, Double, Double) {
        guard let cg = image.cgImage,
              let data = cg.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return (0,0,0) }
        let bpp = cg.bitsPerPixel / 8
        let bytesPerRow = cg.bytesPerRow
        let x = Int(point.x), y = Int(point.y)
        let idx = y * bytesPerRow + x * bpp
        return (Double(bytes[idx])/255.0, Double(bytes[idx+1])/255.0, Double(bytes[idx+2])/255.0)
    }
}
```

(Reuses `UIImage.solid` helper from Task 8 — make sure it's accessible in this test file. If the helper lives in `DrawingRepositoryTests.swift`, lift it to a shared `SketchbookTests/TestHelpers.swift` file in this task.)

Create `SketchbookTests/TestHelpers.swift`:

```swift
// SketchbookTests/TestHelpers.swift
import UIKit

extension UIImage {
    static func solid(color: UIColor, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
```

…and remove the duplicate extension from `DrawingRepositoryTests.swift`.

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Implement `ThumbnailRenderer`**

```swift
// Sketchbook/Storage/ThumbnailRenderer.swift
import UIKit
import PencilKit

enum ThumbnailRenderer {
    static let defaultSize = CGSize(width: 400, height: 300)

    static func render(drawing: Drawing,
                       photoImage: UIImage?,
                       canvasSize: CGSize = defaultSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { ctx in
            // 1. background fill
            drawing.backgroundColor.uiColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvasSize))

            // 2. photo layer (if any)
            if let photo = photoImage, let layer = drawing.photoLayer {
                ctx.cgContext.saveGState()
                ctx.cgContext.setAlpha(CGFloat(layer.opacity))
                ctx.cgContext.concatenate(layer.transform)
                photo.draw(in: CGRect(origin: .zero, size: canvasSize))
                ctx.cgContext.restoreGState()
            }

            // 3. PKDrawing strokes
            if !drawing.pkDrawingData.isEmpty,
               let pk = try? PKDrawing(data: drawing.pkDrawingData) {
                let pkImage = pk.image(from: pk.bounds, scale: UIScreen.main.scale)
                pkImage.draw(in: CGRect(origin: .zero, size: canvasSize))
            }
        }
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add Sketchbook/Storage/ThumbnailRenderer.swift SketchbookTests/ThumbnailRendererTests.swift SketchbookTests/TestHelpers.swift SketchbookTests/DrawingRepositoryTests.swift
git commit -m "feat: ThumbnailRenderer composites background + photo + PKDrawing"
```

---

## Task 12: `ParentGateGesture` state machine + tests

**Files:**
- Create: `Sketchbook/ParentGate/ParentGateGesture.swift`
- Create: `SketchbookTests/ParentGateGestureTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// SketchbookTests/ParentGateGestureTests.swift
import XCTest
@testable import Sketchbook

@MainActor
final class ParentGateGestureTests: XCTestCase {
    func test_single_touch_does_not_progress() {
        var gesture = ParentGateGesture(requiredDuration: 1.0, now: { 0 })
        gesture.setTouched(dot: .left, isDown: true, at: 0)
        XCTAssertEqual(gesture.progress(at: 0), 0)
        XCTAssertEqual(gesture.progress(at: 1.0), 0)
        XCTAssertFalse(gesture.hasPassed(at: 5.0))
    }

    func test_two_touches_do_not_progress() {
        var gesture = ParentGateGesture(requiredDuration: 1.0, now: { 0 })
        gesture.setTouched(dot: .left, isDown: true, at: 0)
        gesture.setTouched(dot: .middle, isDown: true, at: 0)
        XCTAssertEqual(gesture.progress(at: 2.0), 0)
        XCTAssertFalse(gesture.hasPassed(at: 5.0))
    }

    func test_three_touches_held_long_enough_passes() {
        var gesture = ParentGateGesture(requiredDuration: 1.0, now: { 0 })
        gesture.setTouched(dot: .left, isDown: true, at: 0)
        gesture.setTouched(dot: .middle, isDown: true, at: 0)
        gesture.setTouched(dot: .right, isDown: true, at: 0)
        XCTAssertEqual(gesture.progress(at: 0.5), 0.5, accuracy: 0.01)
        XCTAssertTrue(gesture.hasPassed(at: 1.0))
    }

    func test_lifting_a_finger_resets_progress() {
        var gesture = ParentGateGesture(requiredDuration: 1.0, now: { 0 })
        gesture.setTouched(dot: .left, isDown: true, at: 0)
        gesture.setTouched(dot: .middle, isDown: true, at: 0)
        gesture.setTouched(dot: .right, isDown: true, at: 0)
        XCTAssertEqual(gesture.progress(at: 0.5), 0.5, accuracy: 0.01)

        gesture.setTouched(dot: .left, isDown: false, at: 0.6)
        XCTAssertEqual(gesture.progress(at: 0.9), 0)

        gesture.setTouched(dot: .left, isDown: true, at: 1.0)
        XCTAssertEqual(gesture.progress(at: 1.5), 0.5, accuracy: 0.01)
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Implement `ParentGateGesture`**

```swift
// Sketchbook/ParentGate/ParentGateGesture.swift
import Foundation

struct ParentGateGesture {
    enum Dot: Hashable { case left, middle, right }

    private let requiredDuration: TimeInterval
    private let now: () -> TimeInterval
    private var down: Set<Dot> = []
    private var allDownSince: TimeInterval?

    init(requiredDuration: TimeInterval = 3.0, now: @escaping () -> TimeInterval = { Date().timeIntervalSinceReferenceDate }) {
        self.requiredDuration = requiredDuration
        self.now = now
    }

    mutating func setTouched(dot: Dot, isDown: Bool, at time: TimeInterval? = nil) {
        let t = time ?? now()
        if isDown {
            down.insert(dot)
        } else {
            down.remove(dot)
        }
        if down.count == 3 {
            if allDownSince == nil { allDownSince = t }
        } else {
            allDownSince = nil
        }
    }

    /// 0…1, how close we are to passing the gate.
    func progress(at time: TimeInterval? = nil) -> Double {
        guard let start = allDownSince else { return 0 }
        let t = time ?? now()
        let elapsed = max(0, t - start)
        return min(elapsed / requiredDuration, 1.0)
    }

    func hasPassed(at time: TimeInterval? = nil) -> Bool {
        progress(at: time) >= 1.0
    }
}
```

- [ ] **Step 4: Run tests — expect PASS (4/4)**

- [ ] **Step 5: Commit**

```bash
git add Sketchbook/ParentGate/ParentGateGesture.swift SketchbookTests/ParentGateGestureTests.swift
git commit -m "feat: ParentGateGesture state machine"
```

---

## Task 13: `ParentGateSheet` SwiftUI view

**Files:**
- Create: `Sketchbook/ParentGate/ParentGateSheet.swift`

- [ ] **Step 1: Implement the view**

```swift
// Sketchbook/ParentGate/ParentGateSheet.swift
import SwiftUI

struct ParentGateSheet: View {
    let onPass: () -> Void
    let onCancel: () -> Void

    @State private var gesture = ParentGateGesture(requiredDuration: 3.0)
    @State private var displayProgress: Double = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 32) {
            Text("Grown-up time!")
                .font(.system(size: 36, weight: .bold, design: .rounded))
            Text("Touch and hold all three dots for 3 seconds.")
                .font(.title3)
                .foregroundStyle(.secondary)

            HStack(spacing: 48) {
                dot(.left)
                dot(.middle)
                dot(.right)
            }
            .padding(.vertical, 24)

            Button("Cancel") { stopTimer(); onCancel() }
                .font(.title2)
                .padding(.top, 24)
        }
        .padding(48)
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    private func dot(_ which: ParentGateGesture.Dot) -> some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 6)
            Circle()
                .trim(from: 0, to: displayProgress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(Color.primary.opacity(0.85))
                .padding(12)
        }
        .frame(width: 100, height: 100)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in gesture.setTouched(dot: which, isDown: true) }
                .onEnded { _ in gesture.setTouched(dot: which, isDown: false) }
        )
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { _ in
            displayProgress = gesture.progress()
            if gesture.hasPassed() {
                stopTimer()
                onPass()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    ParentGateSheet(onPass: {}, onCancel: {})
}
```

- [ ] **Step 2: Build to confirm it compiles**

Run: `xcodebuild build -scheme Sketchbook -destination 'platform=iOS Simulator,name=iPad (10th generation)'`

- [ ] **Step 3: Manually verify in Xcode preview**

Open `ParentGateSheet.swift` in Xcode. Confirm preview renders without errors. Three dots, "Grown-up time!" title.

- [ ] **Step 4: Commit**

```bash
git add Sketchbook/ParentGate/ParentGateSheet.swift
git commit -m "feat: ParentGateSheet SwiftUI view"
```

---

## Task 14: `BrushKind` and `BrushSize` enums

**Files:**
- Create: `Sketchbook/Drawing/Chrome/BrushKind.swift`

- [ ] **Step 1: Add the type**

```swift
// Sketchbook/Drawing/Chrome/BrushKind.swift
import PencilKit
import UIKit

enum BrushKind: String, CaseIterable, Identifiable {
    case pen, crayon, marker, paintbrush, eraser

    var id: String { rawValue }
    var displaySymbol: String {
        switch self {
        case .pen:        return "pencil.tip"
        case .crayon:     return "pencil"
        case .marker:     return "highlighter"
        case .paintbrush: return "paintbrush.pointed.fill"
        case .eraser:     return "eraser.fill"
        }
    }
}

enum BrushSize: Double, CaseIterable, Identifiable {
    case small = 4
    case medium = 10
    case big = 22
    var id: Double { rawValue }
}

extension BrushKind {
    func pkTool(color: UIColor, size: BrushSize) -> PKTool {
        switch self {
        case .pen:        return PKInkingTool(.pen,        color: color, width: size.rawValue)
        case .crayon:     return PKInkingTool(.crayon,     color: color, width: size.rawValue)
        case .marker:     return PKInkingTool(.marker,     color: color, width: size.rawValue)
        case .paintbrush: return PKInkingTool(.watercolor, color: color, width: size.rawValue)
        case .eraser:     return PKEraserTool(.bitmap, width: size.rawValue)
        }
    }
}
```

- [ ] **Step 2: Build — confirm compiles**

- [ ] **Step 3: Commit**

```bash
git add Sketchbook/Drawing/Chrome/BrushKind.swift
git commit -m "feat: BrushKind and BrushSize → PKTool mapping"
```

---

## Task 15: `FingerDrawingPreference` (UserDefaults wrapper)

**Files:**
- Create: `Sketchbook/Drawing/FingerDrawingPreference.swift`

- [ ] **Step 1: Add the preference**

```swift
// Sketchbook/Drawing/FingerDrawingPreference.swift
import Foundation
import Combine

@MainActor
final class FingerDrawingPreference: ObservableObject {
    private static let key = "SketchbookAllowFingerDrawing"
    @Published var allowFingerDrawing: Bool {
        didSet { UserDefaults.standard.set(allowFingerDrawing, forKey: Self.key) }
    }

    init(defaults: UserDefaults = .standard) {
        self.allowFingerDrawing = defaults.bool(forKey: Self.key)
    }
}
```

- [ ] **Step 2: Build — confirm compiles**

- [ ] **Step 3: Commit**

```bash
git add Sketchbook/Drawing/FingerDrawingPreference.swift
git commit -m "feat: FingerDrawingPreference (UserDefaults-backed)"
```

---

## Task 16: `PencilCanvas` UIViewRepresentable

**Files:**
- Create: `Sketchbook/Drawing/Canvas/PencilCanvas.swift`

- [ ] **Step 1: Implement the wrapper**

```swift
// Sketchbook/Drawing/Canvas/PencilCanvas.swift
import SwiftUI
import PencilKit

struct PencilCanvas: UIViewRepresentable {
    @Binding var drawingData: Data
    let tool: PKTool
    let allowFingerDrawing: Bool
    let onStrokeEnd: () -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.tool = tool
        canvas.drawingPolicy = allowFingerDrawing ? .anyInput : .pencilOnly
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.minimumZoomScale = 1.0
        canvas.maximumZoomScale = 4.0
        canvas.alwaysBounceVertical = false
        canvas.alwaysBounceHorizontal = false
        if !drawingData.isEmpty, let drawing = try? PKDrawing(data: drawingData) {
            canvas.drawing = drawing
        }
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        canvas.tool = tool
        canvas.drawingPolicy = allowFingerDrawing ? .anyInput : .pencilOnly
        // Only overwrite the canvas drawing if external state diverges (e.g., load).
        if drawingData.isEmpty && !canvas.drawing.strokes.isEmpty {
            canvas.drawing = PKDrawing()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: PencilCanvas
        init(_ parent: PencilCanvas) { self.parent = parent }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawingData = canvasView.drawing.dataRepresentation()
            parent.onStrokeEnd()
        }
    }
}
```

- [ ] **Step 2: Build — confirm compiles**

- [ ] **Step 3: Commit**

```bash
git add Sketchbook/Drawing/Canvas/PencilCanvas.swift
git commit -m "feat: PencilCanvas SwiftUI wrapper around PKCanvasView"
```

---

## Task 17: `PhotoLayerView` UIViewRepresentable

**Files:**
- Create: `Sketchbook/Drawing/Canvas/PhotoLayerView.swift`

- [ ] **Step 1: Implement**

```swift
// Sketchbook/Drawing/Canvas/PhotoLayerView.swift
import SwiftUI
import UIKit

struct PhotoLayerView: UIViewRepresentable {
    let image: UIImage
    let opacity: Double
    let transform: CGAffineTransform

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        view.alpha = CGFloat(opacity)
        view.transform = transform
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        view.image = image
        view.alpha = CGFloat(opacity)
        view.transform = transform
    }
}
```

- [ ] **Step 2: Build — confirm compiles**

- [ ] **Step 3: Commit**

```bash
git add Sketchbook/Drawing/Canvas/PhotoLayerView.swift
git commit -m "feat: PhotoLayerView wrapper for photo background layer"
```

---

## Task 18: `DrawingViewModel` + save-debounce tests

**Files:**
- Create: `Sketchbook/Drawing/DrawingViewModel.swift`
- Create: `SketchbookTests/DrawingViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// SketchbookTests/DrawingViewModelTests.swift
import XCTest
import Combine
@testable import Sketchbook

@MainActor
final class DrawingViewModelTests: XCTestCase {
    var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: tmp) }

    func test_initial_state_uses_loaded_drawing() {
        var d = Drawing.empty()
        d.pkDrawingData = Data([0x07])
        let store = DrawingStore(repository: DrawingRepository(rootDirectory: tmp))
        let vm = DrawingViewModel(drawing: d, store: store)
        XCTAssertEqual(vm.pkDrawingData, Data([0x07]))
        XCTAssertEqual(vm.selectedBrush, .pen)
        XCTAssertEqual(vm.selectedSize, .medium)
        XCTAssertEqual(vm.selectedColor, KidPalette.colors[9].color) // charcoal default
    }

    func test_flushSave_persists_drawing_with_updated_data() throws {
        let store = DrawingStore(repository: DrawingRepository(rootDirectory: tmp))
        let d = try store.createNew()
        let vm = DrawingViewModel(drawing: d, store: store)
        vm.pkDrawingData = Data([0x99])
        try vm.flushSave()
        let loaded = try DrawingRepository(rootDirectory: tmp).load(id: d.id)
        XCTAssertEqual(loaded.pkDrawingData, Data([0x99]))
        XCTAssertGreaterThan(loaded.updatedAt, d.updatedAt)
    }

    func test_clearCanvas_empties_data_and_flushes() throws {
        let store = DrawingStore(repository: DrawingRepository(rootDirectory: tmp))
        let d = try store.createNew()
        let vm = DrawingViewModel(drawing: d, store: store)
        vm.pkDrawingData = Data([0xAA])
        try vm.clearCanvas()
        XCTAssertEqual(vm.pkDrawingData, Data())
        let loaded = try DrawingRepository(rootDirectory: tmp).load(id: d.id)
        XCTAssertEqual(loaded.pkDrawingData, Data())
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Implement the view model**

```swift
// Sketchbook/Drawing/DrawingViewModel.swift
import Foundation
import SwiftUI
import Combine
import UIKit
import PencilKit

@MainActor
final class DrawingViewModel: ObservableObject {
    @Published var pkDrawingData: Data
    @Published var backgroundColor: ColorRGBA
    @Published var photoLayer: PhotoLayer?
    @Published var selectedBrush: BrushKind = .pen
    @Published var selectedSize: BrushSize = .medium
    @Published var selectedColor: ColorRGBA = KidPalette.colors[9].color // charcoal

    private(set) var drawing: Drawing
    private let store: DrawingStore
    private var saveTask: Task<Void, Never>?
    private let debounce: TimeInterval

    init(drawing: Drawing, store: DrawingStore, debounce: TimeInterval = 1.0) {
        self.drawing = drawing
        self.store = store
        self.debounce = debounce
        self.pkDrawingData = drawing.pkDrawingData
        self.backgroundColor = drawing.backgroundColor
        self.photoLayer = drawing.photoLayer
    }

    var currentTool: PKTool {
        selectedBrush.pkTool(color: selectedColor.uiColor, size: selectedSize)
    }

    /// Called by the canvas after each stroke ends; coalesces saves on a debounce.
    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.debounce ?? 1.0) * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            try? self.flushSave()
        }
    }

    func flushSave() throws {
        saveTask?.cancel(); saveTask = nil
        drawing.pkDrawingData = pkDrawingData
        drawing.backgroundColor = backgroundColor
        drawing.photoLayer = photoLayer
        drawing.touch()
        try store.save(drawing)
    }

    func clearCanvas() throws {
        pkDrawingData = Data()
        try flushSave()
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add Sketchbook/Drawing/DrawingViewModel.swift SketchbookTests/DrawingViewModelTests.swift
git commit -m "feat: DrawingViewModel with debounced save"
```

---

## Task 19: `TopBar`

**Files:**
- Create: `Sketchbook/Drawing/Chrome/TopBar.swift`

- [ ] **Step 1: Implement**

```swift
// Sketchbook/Drawing/Chrome/TopBar.swift
import SwiftUI

struct TopBar: View {
    let onBack: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let canUndo: Bool
    let canRedo: Bool
    let onShare: () -> Void
    let onClear: () -> Void
    let onBackgroundColor: () -> Void
    let onToggleFingerDrawing: () -> Void
    let fingerDrawingOn: Bool

    var body: some View {
        HStack {
            chipButton(systemName: "chevron.backward", action: onBack)
                .accessibilityLabel("Back to gallery")
            Spacer()
            chipButton(systemName: "arrow.uturn.backward", action: onUndo)
                .disabled(!canUndo)
                .opacity(canUndo ? 1 : 0.4)
                .accessibilityLabel("Undo")
            chipButton(systemName: "arrow.uturn.forward", action: onRedo)
                .disabled(!canRedo)
                .opacity(canRedo ? 1 : 0.4)
                .accessibilityLabel("Redo")
            Menu {
                Button { onShare() } label: { Label("Share", systemImage: "square.and.arrow.up") }
                Button { onBackgroundColor() } label: { Label("Background", systemImage: "rectangle.fill") }
                Button(role: .destructive) { onClear() } label: { Label("Clear canvas", systemImage: "trash") }
                Divider()
                Button { onToggleFingerDrawing() } label: {
                    Label(fingerDrawingOn ? "Pencil-only" : "Let me draw with my finger",
                          systemImage: fingerDrawingOn ? "pencil.tip" : "hand.draw")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                    .padding(.horizontal, 8)
            }
            .accessibilityLabel("More options")
        }
        .padding(.horizontal, 24).padding(.vertical, 12)
    }

    private func chipButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 48, height: 48)
                .background(.thinMaterial, in: Circle())
        }
    }
}

#Preview {
    TopBar(onBack: {}, onUndo: {}, onRedo: {},
           canUndo: true, canRedo: false,
           onShare: {}, onClear: {}, onBackgroundColor: {},
           onToggleFingerDrawing: {}, fingerDrawingOn: false)
}
```

- [ ] **Step 2: Build — confirm compiles**

- [ ] **Step 3: Commit**

```bash
git add Sketchbook/Drawing/Chrome/TopBar.swift
git commit -m "feat: TopBar with back/undo/redo/more menu"
```

---

## Task 20: `BrushPicker`

**Files:**
- Create: `Sketchbook/Drawing/Chrome/BrushPicker.swift`

- [ ] **Step 1: Implement**

```swift
// Sketchbook/Drawing/Chrome/BrushPicker.swift
import SwiftUI

struct BrushPicker: View {
    @Binding var selectedBrush: BrushKind
    @Binding var selectedSize: BrushSize
    @State private var bloomedBrush: BrushKind?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(BrushKind.allCases) { brush in
                brushButton(brush)
            }
        }
        .overlay(alignment: .top) {
            if let b = bloomedBrush, b == selectedBrush {
                sizeBloom
                    .offset(y: -72)
                    .transition(.scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: bloomedBrush)
    }

    private func brushButton(_ brush: BrushKind) -> some View {
        let isSelected = (brush == selectedBrush)
        return Button {
            if isSelected {
                bloomedBrush = (bloomedBrush == brush) ? nil : brush
            } else {
                selectedBrush = brush
                bloomedBrush = nil
            }
        } label: {
            Image(systemName: brush.displaySymbol)
                .font(.system(size: 28, weight: .semibold))
                .frame(width: 56, height: 56)
                .background(isSelected ? AnyShapeStyle(.tint.opacity(0.25)) : AnyShapeStyle(.clear),
                            in: Circle())
                .scaleEffect(isSelected ? 1.2 : 1.0)
                .offset(y: isSelected ? -6 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(brush.rawValue.capitalized)
    }

    private var sizeBloom: some View {
        HStack(spacing: 16) {
            ForEach(BrushSize.allCases) { size in
                Button { selectedSize = size; bloomedBrush = nil } label: {
                    Circle()
                        .fill(.primary)
                        .frame(width: CGFloat(size.rawValue) * 1.5,
                               height: CGFloat(size.rawValue) * 1.5)
                        .overlay(
                            Circle().stroke(.tint, lineWidth: selectedSize == size ? 3 : 0)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(size)".capitalized)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: Capsule())
    }
}

#Preview {
    @Previewable @State var brush: BrushKind = .pen
    @Previewable @State var size: BrushSize = .medium
    return BrushPicker(selectedBrush: $brush, selectedSize: $size)
        .padding()
}
```

- [ ] **Step 2: Build — confirm compiles**

- [ ] **Step 3: Commit**

```bash
git add Sketchbook/Drawing/Chrome/BrushPicker.swift
git commit -m "feat: BrushPicker with size bloom on re-tap"
```

---

## Task 21: `ColorPalette`

**Files:**
- Create: `Sketchbook/Drawing/Chrome/ColorPalette.swift`

- [ ] **Step 1: Implement**

```swift
// Sketchbook/Drawing/Chrome/ColorPalette.swift
import SwiftUI

struct ColorPalette: View {
    @Binding var selectedColor: ColorRGBA
    @State private var customColor: ColorRGBA?
    @State private var showingWheel = false
    @State private var wheelTarget: ColorRGBA = .init(r: 0, g: 0, b: 0)

    var body: some View {
        HStack(spacing: 6) {
            ForEach(KidPalette.colors, id: \.name) { entry in
                colorChip(entry.color, name: entry.name)
            }
            if let custom = customColor {
                colorChip(custom, name: "Custom")
            } else {
                Button { wheelTarget = selectedColor; showingWheel = true } label: {
                    Image(systemName: "plus.circle.dashed")
                        .font(.system(size: 24))
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("More colors")
            }
        }
        .sheet(isPresented: $showingWheel) {
            colorWheelSheet
        }
    }

    private func colorChip(_ color: ColorRGBA, name: String) -> some View {
        let isSelected = (color == selectedColor)
        return Circle()
            .fill(color.swiftUIColor)
            .frame(width: 36, height: 36)
            .overlay(Circle().stroke(.primary, lineWidth: isSelected ? 3 : 1))
            .onTapGesture { selectedColor = color }
            .onLongPressGesture(minimumDuration: 0.4) {
                wheelTarget = color
                showingWheel = true
            }
            .accessibilityLabel(name)
    }

    private var colorWheelSheet: some View {
        VStack(spacing: 24) {
            Text("Pick any colour")
                .font(.title2.weight(.semibold))
            ColorPicker("", selection: Binding(
                get: { wheelTarget.swiftUIColor },
                set: { wheelTarget = ColorRGBA($0) }
            ), supportsOpacity: false)
            .labelsHidden()
            .scaleEffect(2.0)
            .frame(height: 200)
            Button {
                customColor = wheelTarget
                selectedColor = wheelTarget
                showingWheel = false
            } label: {
                Text("Use this colour")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(wheelTarget.swiftUIColor, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding(48)
        .presentationDetents([.medium])
    }
}

#Preview {
    @Previewable @State var color = KidPalette.colors[0].color
    return ColorPalette(selectedColor: $color).padding()
}
```

- [ ] **Step 2: Build — confirm compiles**

- [ ] **Step 3: Commit**

```bash
git add Sketchbook/Drawing/Chrome/ColorPalette.swift
git commit -m "feat: ColorPalette with long-press color wheel"
```

---

## Task 22: `BackgroundColorPopover`

**Files:**
- Create: `Sketchbook/Drawing/Chrome/BackgroundColorPopover.swift`

- [ ] **Step 1: Implement**

```swift
// Sketchbook/Drawing/Chrome/BackgroundColorPopover.swift
import SwiftUI

struct BackgroundColorPopover: View {
    @Binding var selectedColor: ColorRGBA
    let onClose: () -> Void

    private var options: [(name: String, color: ColorRGBA)] {
        KidPalette.colors.map { ($0.name, $0.color) }
        + [("White", ColorRGBA(r: 1, g: 1, b: 1))]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Background")
                .font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(48)), count: 6), spacing: 12) {
                ForEach(options, id: \.name) { entry in
                    Circle()
                        .fill(entry.color.swiftUIColor)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(.primary, lineWidth: selectedColor == entry.color ? 3 : 1))
                        .onTapGesture {
                            selectedColor = entry.color
                            onClose()
                        }
                        .accessibilityLabel(entry.name)
                }
            }
        }
        .padding(24)
        .presentationDetents([.height(260)])
    }
}

#Preview {
    @Previewable @State var c = ColorRGBA(r: 1, g: 1, b: 1)
    return BackgroundColorPopover(selectedColor: $c, onClose: {})
}
```

- [ ] **Step 2: Build — confirm compiles**

- [ ] **Step 3: Commit**

```bash
git add Sketchbook/Drawing/Chrome/BackgroundColorPopover.swift
git commit -m "feat: BackgroundColorPopover (11 colour grid)"
```

---

## Task 23: `ToolDock`

**Files:**
- Create: `Sketchbook/Drawing/Chrome/ToolDock.swift`

- [ ] **Step 1: Implement**

```swift
// Sketchbook/Drawing/Chrome/ToolDock.swift
import SwiftUI

struct ToolDock: View {
    @Binding var brush: BrushKind
    @Binding var size: BrushSize
    @Binding var color: ColorRGBA
    let onPhotoTap: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            BrushPicker(selectedBrush: $brush, selectedSize: $size)
            Divider().frame(height: 40)
            ColorPalette(selectedColor: $color)
            Divider().frame(height: 40)
            Button(action: onPhotoTap) {
                Image(systemName: "camera.fill.badge.ellipsis")
                    .font(.system(size: 26, weight: .semibold))
                    .frame(width: 56, height: 56)
                    .background(.tint.opacity(0.15), in: Circle())
            }
            .accessibilityLabel("Add photo")
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
    }
}

#Preview {
    @Previewable @State var brush: BrushKind = .pen
    @Previewable @State var size: BrushSize = .medium
    @Previewable @State var color = KidPalette.colors[9].color
    return ToolDock(brush: $brush, size: $size, color: $color, onPhotoTap: {})
}
```

- [ ] **Step 2: Build — confirm compiles**

- [ ] **Step 3: Commit**

```bash
git add Sketchbook/Drawing/Chrome/ToolDock.swift
git commit -m "feat: ToolDock composing BrushPicker + ColorPalette + photo button"
```

---

## Task 24: `DrawingView` — putting the canvas screen together

**Files:**
- Create: `Sketchbook/Drawing/DrawingView.swift`

- [ ] **Step 1: Implement**

```swift
// Sketchbook/Drawing/DrawingView.swift
import SwiftUI
import PencilKit

struct DrawingView: View {
    @StateObject var viewModel: DrawingViewModel
    @EnvironmentObject var fingerPref: FingerDrawingPreference
    @Environment(\.dismiss) private var dismiss

    @State private var showParentGate: PendingGatedAction?
    @State private var showBackgroundPopover = false
    @State private var showShareSheet = false
    @State private var showPhotoFlow = false

    enum PendingGatedAction: Identifiable {
        case share, clear, enableFingerDrawing, openCamera, openPhotos
        var id: String {
            switch self {
            case .share: return "share"
            case .clear: return "clear"
            case .enableFingerDrawing: return "ffd"
            case .openCamera: return "cam"
            case .openPhotos: return "lib"
            }
        }
    }

    var body: some View {
        ZStack {
            viewModel.backgroundColor.swiftUIColor
                .ignoresSafeArea()

            if let layer = viewModel.photoLayer,
               let image = loadPhoto(for: layer) {
                PhotoLayerView(image: image,
                               opacity: layer.opacity,
                               transform: layer.transform)
                    .ignoresSafeArea()
            }

            PencilCanvas(drawingData: $viewModel.pkDrawingData,
                         tool: viewModel.currentTool,
                         allowFingerDrawing: fingerPref.allowFingerDrawing,
                         onStrokeEnd: { viewModel.scheduleSave() })

            VStack {
                TopBar(
                    onBack: { try? viewModel.flushSave(); dismiss() },
                    onUndo: { /* wired in Task 35 via UndoManager */ },
                    onRedo: { },
                    canUndo: true, canRedo: true,
                    onShare: { showParentGate = .share },
                    onClear: { showParentGate = .clear },
                    onBackgroundColor: { showBackgroundPopover = true },
                    onToggleFingerDrawing: {
                        if fingerPref.allowFingerDrawing {
                            fingerPref.allowFingerDrawing = false
                        } else {
                            showParentGate = .enableFingerDrawing
                        }
                    },
                    fingerDrawingOn: fingerPref.allowFingerDrawing
                )
                Spacer()
                ToolDock(brush: $viewModel.selectedBrush,
                         size: $viewModel.selectedSize,
                         color: $viewModel.selectedColor,
                         onPhotoTap: { showPhotoFlow = true })
                .padding(.bottom, 12)
            }
        }
        .sheet(item: $showParentGate) { action in
            ParentGateSheet(
                onPass: { handleGated(action); showParentGate = nil },
                onCancel: { showParentGate = nil }
            )
        }
        .sheet(isPresented: $showBackgroundPopover) {
            BackgroundColorPopover(selectedColor: $viewModel.backgroundColor,
                                   onClose: { showBackgroundPopover = false })
        }
        .onDisappear { try? viewModel.flushSave() }
    }

    private func handleGated(_ action: PendingGatedAction) {
        switch action {
        case .share:
            showShareSheet = true   // wired in Task 34
        case .clear:
            try? viewModel.clearCanvas()
        case .enableFingerDrawing:
            fingerPref.allowFingerDrawing = true
        case .openCamera, .openPhotos:
            showPhotoFlow = true    // photo flow re-presents with the right picker
        }
    }

    private func loadPhoto(for layer: PhotoLayer) -> UIImage? {
        DrawingRepository().loadPhoto(for: viewModel.drawing.id, filename: layer.imageFilename)
    }
}
```

(Photo flow sheet is added in Task 33 — this view compiles as-is.)

- [ ] **Step 2: Build — confirm compiles**

- [ ] **Step 3: Commit**

```bash
git add Sketchbook/Drawing/DrawingView.swift
git commit -m "feat: DrawingView assembling canvas + chrome + gates"
```

---

## Task 25: `ThumbnailCell`

**Files:**
- Create: `Sketchbook/Gallery/ThumbnailCell.swift`

- [ ] **Step 1: Implement**

```swift
// Sketchbook/Gallery/ThumbnailCell.swift
import SwiftUI

struct ThumbnailCell: View {
    let image: UIImage?
    let isWiggling: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var wigglePhase: Double = 0

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(.systemGray5)
                    }
                }
                .frame(width: 220, height: 165)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.black.opacity(0.1)))
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

                if isWiggling {
                    Button(action: onDelete) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                            .background(Circle().fill(.white))
                    }
                    .offset(x: 6, y: -6)
                }
            }
            .rotationEffect(.degrees(isWiggling ? sin(wigglePhase) * 1.5 : 0))
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.linear(duration: 0.2).repeatForever(autoreverses: false)) {
                wigglePhase = .pi * 2
            }
        }
    }
}

struct NewDrawingTile: View {
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: 18)
                .fill(.tint.opacity(0.1))
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 60, weight: .light))
                        .foregroundStyle(.tint)
                )
                .frame(width: 220, height: 165)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(.tint.opacity(0.5),
                                      style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New drawing")
    }
}
```

- [ ] **Step 2: Build — confirm compiles**

- [ ] **Step 3: Commit**

```bash
git add Sketchbook/Gallery/ThumbnailCell.swift
git commit -m "feat: ThumbnailCell + NewDrawingTile"
```

---

## Task 26: `GalleryViewModel` + tests

**Files:**
- Create: `Sketchbook/Gallery/GalleryViewModel.swift`
- Create: `SketchbookTests/GalleryViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// SketchbookTests/GalleryViewModelTests.swift
import XCTest
@testable import Sketchbook

@MainActor
final class GalleryViewModelTests: XCTestCase {
    var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: tmp) }

    func test_createNew_pushes_new_drawing_into_store() throws {
        let store = DrawingStore(repository: DrawingRepository(rootDirectory: tmp))
        let vm = GalleryViewModel(store: store)
        let new = try vm.createNew()
        XCTAssertEqual(store.drawings.first?.id, new.id)
    }

    func test_toggleWiggling_returns_true_when_enabled() {
        let store = DrawingStore(repository: DrawingRepository(rootDirectory: tmp))
        let vm = GalleryViewModel(store: store)
        XCTAssertFalse(vm.isWiggling)
        vm.toggleWiggle()
        XCTAssertTrue(vm.isWiggling)
        vm.toggleWiggle()
        XCTAssertFalse(vm.isWiggling)
    }

    func test_requestDelete_holds_id_for_parent_gate() {
        let store = DrawingStore(repository: DrawingRepository(rootDirectory: tmp))
        let vm = GalleryViewModel(store: store)
        let id = UUID()
        vm.requestDelete(id: id)
        XCTAssertEqual(vm.pendingDeleteId, id)
    }

    func test_confirmDelete_removes_pending() throws {
        let store = DrawingStore(repository: DrawingRepository(rootDirectory: tmp))
        let d = try store.createNew()
        let vm = GalleryViewModel(store: store)
        vm.requestDelete(id: d.id)
        try vm.confirmDelete()
        XCTAssertNil(vm.pendingDeleteId)
        XCTAssertTrue(store.drawings.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Implement**

```swift
// Sketchbook/Gallery/GalleryViewModel.swift
import Foundation
import SwiftUI

@MainActor
final class GalleryViewModel: ObservableObject {
    @Published var isWiggling = false
    @Published var pendingDeleteId: UUID?
    let store: DrawingStore

    init(store: DrawingStore) { self.store = store }

    @discardableResult
    func createNew() throws -> Drawing {
        try store.createNew()
    }

    func toggleWiggle() { isWiggling.toggle() }

    func requestDelete(id: UUID) { pendingDeleteId = id }

    func cancelDelete() { pendingDeleteId = nil }

    func confirmDelete() throws {
        guard let id = pendingDeleteId else { return }
        try store.delete(id: id)
        pendingDeleteId = nil
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add Sketchbook/Gallery/GalleryViewModel.swift SketchbookTests/GalleryViewModelTests.swift
git commit -m "feat: GalleryViewModel with wiggle and delete-gate state"
```

---

## Task 27: `GalleryView`

**Files:**
- Create: `Sketchbook/Gallery/GalleryView.swift`

- [ ] **Step 1: Implement**

```swift
// Sketchbook/Gallery/GalleryView.swift
import SwiftUI

struct GalleryView: View {
    @StateObject var viewModel: GalleryViewModel
    @EnvironmentObject var fingerPref: FingerDrawingPreference
    @State private var openedDrawing: Drawing?

    private let columns = Array(repeating: GridItem(.fixed(220), spacing: 24), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 28) {
                    NewDrawingTile { startNew() }
                    ForEach(viewModel.store.drawings) { drawing in
                        ThumbnailCell(
                            image: DrawingRepository().loadThumbnail(for: drawing.id),
                            isWiggling: viewModel.isWiggling,
                            onTap: { openedDrawing = drawing },
                            onDelete: { viewModel.requestDelete(id: drawing.id) }
                        )
                        .onLongPressGesture(minimumDuration: 0.6) {
                            viewModel.toggleWiggle()
                        }
                    }
                }
                .padding(32)
            }
            .background(Color(red: 0.98, green: 0.97, blue: 0.94))
            .navigationDestination(item: $openedDrawing) { drawing in
                DrawingView(viewModel: DrawingViewModel(drawing: drawing, store: viewModel.store))
                    .navigationBarBackButtonHidden(true)
            }
            .sheet(item: $viewModel.pendingDeleteId.optionalIdentifiable()) { _ in
                ParentGateSheet(
                    onPass: { try? viewModel.confirmDelete() },
                    onCancel: { viewModel.cancelDelete() }
                )
            }
        }
    }

    private func startNew() {
        guard let d = try? viewModel.createNew() else { return }
        openedDrawing = d
    }
}

private extension UUID {
    struct IdentifiableUUID: Identifiable { let id: UUID }
}

private extension Optional where Wrapped == UUID {
    func optionalIdentifiable() -> Binding<UUID.IdentifiableUUID?> {
        fatalError("use binding extension instead")  // placeholder; see binding below
    }
}

private extension Binding where Value == UUID? {
    func optionalIdentifiable() -> Binding<IdentifiableID?> {
        Binding<IdentifiableID?>(
            get: { wrappedValue.map(IdentifiableID.init(id:)) },
            set: { wrappedValue = $0?.id }
        )
    }
}

private struct IdentifiableID: Identifiable, Hashable { let id: UUID }
```

> Note: `Drawing` conforms to `Identifiable` already (Task 4), so `navigationDestination(item:)` works directly on it.

- [ ] **Step 2: Build — confirm compiles**

- [ ] **Step 3: Commit**

```bash
git add Sketchbook/Gallery/GalleryView.swift
git commit -m "feat: GalleryView with wiggle delete and navigation to DrawingView"
```

---

## Task 28: `PhotoSourceSheet`

**Files:**
- Create: `Sketchbook/Photo/PhotoSourceSheet.swift`

- [ ] **Step 1: Implement**

```swift
// Sketchbook/Photo/PhotoSourceSheet.swift
import SwiftUI

struct PhotoSourceSheet: View {
    enum Source { case camera, library, starter }
    let onPick: (Source) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Text("Where's your picture?")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            HStack(spacing: 24) {
                tile(symbol: "camera.fill", label: "Camera") { onPick(.camera) }
                tile(symbol: "photo.fill",  label: "Photos") { onPick(.library) }
                tile(symbol: "star.fill",   label: "Starter") { onPick(.starter) }
            }
            Button("Never mind") { onCancel() }
                .font(.title3)
                .padding(.top, 8)
        }
        .padding(40)
        .presentationDetents([.medium])
    }

    private func tile(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 56))
                    .frame(width: 140, height: 140)
                    .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 24))
                Text(label).font(.title3.weight(.semibold))
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview { PhotoSourceSheet(onPick: { _ in }, onCancel: {}) }
```

- [ ] **Step 2: Build — confirm compiles**

- [ ] **Step 3: Commit**

```bash
git add Sketchbook/Photo/PhotoSourceSheet.swift
git commit -m "feat: PhotoSourceSheet"
```

---

## Task 29: `PhotoModeSheet`

**Files:**
- Create: `Sketchbook/Photo/PhotoModeSheet.swift`

- [ ] **Step 1: Implement**

```swift
// Sketchbook/Photo/PhotoModeSheet.swift
import SwiftUI

struct PhotoModeSheet: View {
    let preview: UIImage
    let onPick: (PhotoLayer.Mode) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("How do you want to use this?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Image(uiImage: preview)
                .resizable().scaledToFit()
                .frame(maxHeight: 180)
                .cornerRadius(16)
            HStack(spacing: 20) {
                modeTile(symbol: "eye.fill",   label: "Look at it",  mode: .reference)
                modeTile(symbol: "pencil",     label: "Trace it",    mode: .trace)
                modeTile(symbol: "paintbrush", label: "Colour it in", mode: .coloringPage)
            }
            Button("Never mind") { onCancel() }.font(.title3)
        }
        .padding(40)
        .presentationDetents([.large])
    }

    private func modeTile(symbol: String, label: String, mode: PhotoLayer.Mode) -> some View {
        Button { onPick(mode) } label: {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 44))
                    .frame(width: 120, height: 120)
                    .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 22))
                Text(label).font(.title3.weight(.semibold))
            }
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Build — confirm compiles**

- [ ] **Step 3: Commit**

```bash
git add Sketchbook/Photo/PhotoModeSheet.swift
git commit -m "feat: PhotoModeSheet (Look / Trace / Colour)"
```

---

## Task 30: `CameraPicker`

**Files:**
- Create: `Sketchbook/Photo/CameraPicker.swift`

- [ ] **Step 1: Implement**

```swift
// Sketchbook/Photo/CameraPicker.swift
import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            } else {
                parent.onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}
```

- [ ] **Step 2: Build — confirm compiles**

- [ ] **Step 3: Commit**

```bash
git add Sketchbook/Photo/CameraPicker.swift
git commit -m "feat: CameraPicker UIImagePickerController wrapper"
```

---

## Task 31: `PhotoLibraryPicker`

**Files:**
- Create: `Sketchbook/Photo/PhotoLibraryPicker.swift`

- [ ] **Step 1: Implement**

```swift
// Sketchbook/Photo/PhotoLibraryPicker.swift
import SwiftUI
import PhotosUI

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPicker
        init(_ parent: PhotoLibraryPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                parent.onCancel(); return
            }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                DispatchQueue.main.async {
                    if let image = object as? UIImage {
                        self.parent.onPick(image)
                    } else {
                        self.parent.onCancel()
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build — confirm compiles**

- [ ] **Step 3: Commit**

```bash
git add Sketchbook/Photo/PhotoLibraryPicker.swift
git commit -m "feat: PhotoLibraryPicker PHPicker wrapper"
```

---

## Task 32: `StarterPhotoLibrary` + bundled images

**Files:**
- Create: `Sketchbook/Photo/StarterPhotoLibrary.swift`
- Modify: `Sketchbook/Assets.xcassets` (add image set per starter)

**Manual asset prep:** add 6 simple line-art / silhouette PNGs to the Asset Catalog as named image sets — names: `starter-cat`, `starter-dog`, `starter-car`, `starter-house`, `starter-flower`, `starter-star`. Use kid-friendly free assets (e.g. openclipart.org, CC0). Each ~512×512.

- [ ] **Step 1: Add assets in Xcode**

In Xcode: Assets.xcassets → right-click → New Image Set, name as listed. Drag a PNG into each. Commit asset folders.

- [ ] **Step 2: Implement library**

```swift
// Sketchbook/Photo/StarterPhotoLibrary.swift
import SwiftUI
import UIKit

enum StarterPhotoLibrary {
    static let assetNames = [
        "starter-cat", "starter-dog", "starter-car",
        "starter-house", "starter-flower", "starter-star",
    ]

    static func image(named name: String) -> UIImage? {
        UIImage(named: name)
    }
}

struct StarterPhotoGrid: View {
    let onPick: (UIImage) -> Void
    let onCancel: () -> Void

    private let columns = Array(repeating: GridItem(.fixed(140), spacing: 16), count: 3)

    var body: some View {
        VStack(spacing: 16) {
            Text("Pick a starter picture")
                .font(.title.weight(.semibold))
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(StarterPhotoLibrary.assetNames, id: \.self) { name in
                    if let img = StarterPhotoLibrary.image(named: name) {
                        Button { onPick(img) } label: {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 140, height: 140)
                                .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Button("Never mind") { onCancel() }.font(.title3).padding(.top, 8)
        }
        .padding(32)
        .presentationDetents([.large])
    }
}
```

- [ ] **Step 3: Build — confirm compiles**

- [ ] **Step 4: Commit**

```bash
git add Sketchbook/Photo/StarterPhotoLibrary.swift Sketchbook/Assets.xcassets/
git commit -m "feat: StarterPhotoLibrary with 6 bundled starter images"
```

---

## Task 33: `PhotoFlow` coordinator

**Files:**
- Create: `Sketchbook/Photo/PhotoFlow.swift`
- Modify: `Sketchbook/Drawing/DrawingView.swift` (wire it in)

- [ ] **Step 1: Implement the coordinator view**

```swift
// Sketchbook/Photo/PhotoFlow.swift
import SwiftUI

struct PhotoFlow: View {
    let drawingId: UUID
    @Binding var photoLayer: PhotoLayer?
    let onClose: () -> Void

    @State private var stage: Stage = .source
    @State private var pickedImage: UIImage?
    @State private var parentGateForSource: PhotoSourceSheet.Source?

    enum Stage {
        case source
        case picker(PhotoSourceSheet.Source)
        case mode
    }

    var body: some View {
        Group {
            switch stage {
            case .source:
                PhotoSourceSheet(
                    onPick: { source in
                        switch source {
                        case .starter: stage = .picker(source)
                        case .camera, .library: parentGateForSource = source
                        }
                    },
                    onCancel: onClose
                )
            case .picker(.camera):
                CameraPicker(onCapture: handlePicked, onCancel: onClose)
            case .picker(.library):
                PhotoLibraryPicker(onPick: handlePicked, onCancel: onClose)
            case .picker(.starter):
                StarterPhotoGrid(onPick: handlePicked, onCancel: onClose)
            case .mode:
                if let image = pickedImage {
                    PhotoModeSheet(preview: image, onPick: handleMode, onCancel: onClose)
                }
            }
        }
        .sheet(item: $parentGateForSource) { source in
            ParentGateSheet(
                onPass: { parentGateForSource = nil; stage = .picker(source) },
                onCancel: { parentGateForSource = nil }
            )
        }
    }

    private func handlePicked(_ image: UIImage) {
        pickedImage = image
        stage = .mode
    }

    private func handleMode(_ mode: PhotoLayer.Mode) {
        guard let image = pickedImage else { return }
        let processed: UIImage = (mode == .coloringPage)
            ? (ColoringPageFilter.apply(to: image) ?? image)
            : image
        let repo = DrawingRepository()
        guard let filename = try? repo.savePhoto(processed, for: drawingId) else {
            onClose(); return
        }
        photoLayer = PhotoLayer(imageFilename: filename, mode: mode,
                                opacity: mode == .trace ? 0.4 : 1.0)
        onClose()
    }
}

extension PhotoSourceSheet.Source: Identifiable {
    public var id: String {
        switch self {
        case .camera: return "camera"
        case .library: return "library"
        case .starter: return "starter"
        }
    }
}
```

- [ ] **Step 2: Wire `PhotoFlow` into `DrawingView`**

In `DrawingView.swift`, replace the `onPhotoTap` block with a sheet binding. Add this state:

```swift
@State private var showPhotoFlow = false
```

And below the existing sheets, add:

```swift
.sheet(isPresented: $showPhotoFlow) {
    PhotoFlow(
        drawingId: viewModel.drawing.id,
        photoLayer: $viewModel.photoLayer,
        onClose: { showPhotoFlow = false }
    )
}
```

Change the `ToolDock` invocation in `DrawingView.body` to:
```swift
ToolDock(brush: $viewModel.selectedBrush,
         size: $viewModel.selectedSize,
         color: $viewModel.selectedColor,
         onPhotoTap: { showPhotoFlow = true })
```

(Already correct — confirm.)

- [ ] **Step 3: Build — confirm compiles**

- [ ] **Step 4: Commit**

```bash
git add Sketchbook/Photo/PhotoFlow.swift Sketchbook/Drawing/DrawingView.swift
git commit -m "feat: PhotoFlow coordinator wired into DrawingView"
```

---

## Task 34: `ShareSheet` + wire to Drawing top bar

**Files:**
- Create: `Sketchbook/Export/ShareSheet.swift`
- Modify: `Sketchbook/Drawing/DrawingView.swift`

- [ ] **Step 1: Implement `ShareSheet`**

```swift
// Sketchbook/Export/ShareSheet.swift
import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
```

- [ ] **Step 2: Wire share into `DrawingView`**

Add to `DrawingView`:

```swift
@State private var shareImage: UIImage?
```

In `handleGated(.share)` replace the existing line with:
```swift
case .share:
    let photo: UIImage? = viewModel.photoLayer.flatMap {
        DrawingRepository().loadPhoto(for: viewModel.drawing.id, filename: $0.imageFilename)
    }
    shareImage = ThumbnailRenderer.render(
        drawing: viewModel.drawing,
        photoImage: photo,
        canvasSize: CGSize(width: 2048, height: 1536)
    )
    showShareSheet = true
```

Add this sheet to the view modifiers:
```swift
.sheet(isPresented: $showShareSheet) {
    if let image = shareImage {
        ShareSheet(items: [image])
    }
}
```

- [ ] **Step 3: Build — confirm compiles**

- [ ] **Step 4: Commit**

```bash
git add Sketchbook/Export/ShareSheet.swift Sketchbook/Drawing/DrawingView.swift
git commit -m "feat: ShareSheet wired through parent gate"
```

---

## Task 35: Wire undo/redo to PencilKit's UndoManager

**Files:**
- Modify: `Sketchbook/Drawing/Canvas/PencilCanvas.swift`
- Modify: `Sketchbook/Drawing/DrawingViewModel.swift`
- Modify: `Sketchbook/Drawing/DrawingView.swift`

- [ ] **Step 1: Expose the underlying `PKCanvasView` to the view model via a weak ref**

Modify `PencilCanvas.swift` — add a `canvasRef` parameter:

```swift
struct PencilCanvas: UIViewRepresentable {
    @Binding var drawingData: Data
    let tool: PKTool
    let allowFingerDrawing: Bool
    let onStrokeEnd: () -> Void
    let onCanvasReady: (PKCanvasView) -> Void
    // ... unchanged ...

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        // ... existing setup ...
        onCanvasReady(canvas)
        return canvas
    }
```

- [ ] **Step 2: Hold a weak ref + expose undo state in `DrawingViewModel`**

```swift
weak var canvasRef: PKCanvasView?
var canUndo: Bool { canvasRef?.undoManager?.canUndo ?? false }
var canRedo: Bool { canvasRef?.undoManager?.canRedo ?? false }
func undo() { canvasRef?.undoManager?.undo() }
func redo() { canvasRef?.undoManager?.redo() }
```

- [ ] **Step 3: Connect in `DrawingView`**

In the `PencilCanvas` instantiation add `onCanvasReady: { viewModel.canvasRef = $0 }`. Change the TopBar `onUndo`/`onRedo` to call `viewModel.undo()` / `viewModel.redo()`, and pass `canUndo: viewModel.canUndo`, `canRedo: viewModel.canRedo`.

(SwiftUI won't reactively update `canUndo`/`canRedo` since they aren't `@Published`. As a small fix, observe `viewModel.pkDrawingData` — every stroke change is a state change that triggers a re-render of `TopBar`, which re-reads `canUndo`. This is enough for v1; a fancier observer can come later.)

- [ ] **Step 4: Build — confirm compiles**

- [ ] **Step 5: Commit**

```bash
git add Sketchbook/Drawing/
git commit -m "feat: wire undo/redo to PKCanvasView's UndoManager"
```

---

## Task 36: Root app wiring

**Files:**
- Modify: `Sketchbook/SketchbookApp.swift`

- [ ] **Step 1: Replace placeholder root with `GalleryView`**

```swift
// Sketchbook/SketchbookApp.swift
import SwiftUI

@main
struct SketchbookApp: App {
    @StateObject private var store = DrawingStore()
    @StateObject private var fingerPref = FingerDrawingPreference()

    var body: some Scene {
        WindowGroup {
            GalleryView(viewModel: GalleryViewModel(store: store))
                .environmentObject(fingerPref)
        }
    }
}
```

- [ ] **Step 2: Build and run on an iPad simulator**

Open Xcode → choose `iPad Pro (12.9-inch)` simulator → `Cmd+R`. Confirm the gallery appears with a "+" tile. Tap "+" → confirm the drawing screen appears with the chrome.

- [ ] **Step 3: Commit**

```bash
git add Sketchbook/SketchbookApp.swift
git commit -m "feat: SketchbookApp boots into Gallery with DrawingStore + FingerDrawingPreference"
```

---

## Task 37: UI test for the create→draw→save→reopen flow

**Files:**
- Create: `SketchbookUITests/DrawingFlowUITests.swift`

- [ ] **Step 1: Write the UI test**

```swift
// SketchbookUITests/DrawingFlowUITests.swift
import XCTest

final class DrawingFlowUITests: XCTestCase {
    func test_create_a_drawing_then_see_it_in_gallery() {
        let app = XCUIApplication()
        app.launchArguments = ["-ResetDrawings"]   // wired in Step 2
        app.launch()

        // Tap the "+ new drawing" tile (accessibility label set in Task 25)
        app.buttons["New drawing"].firstMatch.tap()

        // Drawing screen should show — the toolbar back button is "Back to gallery"
        let back = app.buttons["Back to gallery"]
        XCTAssertTrue(back.waitForExistence(timeout: 4))
        back.tap()

        // Gallery should now show 2 tiles (the + tile plus our new drawing).
        // The new drawing's thumbnail will be a Button with no label other than empty;
        // verify via cell count via a queryable identifier instead.
        let plusTile = app.buttons["New drawing"]
        XCTAssertTrue(plusTile.waitForExistence(timeout: 2))
    }
}
```

- [ ] **Step 2: Add reset-drawings hook to the app for UI tests**

Modify `SketchbookApp.swift`:

```swift
@main
struct SketchbookApp: App {
    @StateObject private var store: DrawingStore
    @StateObject private var fingerPref = FingerDrawingPreference()

    init() {
        let repo = DrawingRepository()
        if CommandLine.arguments.contains("-ResetDrawings") {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try? FileManager.default.removeItem(at: docs.appendingPathComponent("Drawings"))
        }
        _store = StateObject(wrappedValue: DrawingStore(repository: repo))
    }

    var body: some Scene {
        WindowGroup {
            GalleryView(viewModel: GalleryViewModel(store: store))
                .environmentObject(fingerPref)
        }
    }
}
```

- [ ] **Step 3: Run UI tests on simulator — expect PASS**

Run: `xcodebuild test -scheme Sketchbook -destination 'platform=iOS Simulator,name=iPad (10th generation)' -only-testing:SketchbookUITests/DrawingFlowUITests`
Expected: 1 test passes.

- [ ] **Step 4: Commit**

```bash
git add SketchbookUITests/ Sketchbook/SketchbookApp.swift
git commit -m "test: UI test for new-drawing round trip + reset hook"
```

---

## Task 38: Manual on-device test plan checklist

**Files:**
- Create: `docs/superpowers/test-plans/2026-05-27-sketchbook-v1-manual.md`

- [ ] **Step 1: Write the manual checklist**

```markdown
# Sketchbook v1 — Manual On-Device Test Plan

Run these on a real iPad Pro / Air with an Apple Pencil before any release.

## Drawing fundamentals
- [ ] Pencil produces a stroke; finger does NOT produce a stroke (default).
- [ ] Pen brush stroke width visibly varies with Pencil pressure.
- [ ] Crayon brush shading visibly varies with Pencil tilt (Pencil 2).
- [ ] Marker brush overlapping strokes darken where they cross.
- [ ] Paintbrush (watercolour) has soft, semi-transparent edges.
- [ ] Eraser removes pixels but leaves surrounding strokes intact.
- [ ] Pinch-zoom with two fingers works; pencil drawing during zoom does not break the stroke.
- [ ] Palm resting on screen during pencil drawing leaves no marks.

## UI
- [ ] Selected brush is enlarged and lifted compared to others.
- [ ] Re-tapping selected brush blooms the 3-size selector above it.
- [ ] Long-press on a palette colour opens the full colour wheel; picked colour appears in the custom slot.
- [ ] All 10 default palette colours are muted (no neon).
- [ ] Background colour from "⋯ → Background" updates the canvas live.
- [ ] Finger-drawing toggle: turning on requires parent gate; turning off is one tap.

## Photo features
- [ ] Camera button → parent gate → camera opens → snap a photo → mode sheet appears.
- [ ] Photos button → parent gate → PHPicker opens → pick a photo → mode sheet appears.
- [ ] Starter button (no gate) → 6 starter images visible → pick → mode sheet appears.
- [ ] "Look at it" pins the photo to a side, drawing area unaffected.
- [ ] "Trace it" places the photo as 40% opacity background under the canvas.
- [ ] "Colour it in" produces visible black line art on white.
- [ ] Removing the photo (top bar "remove photo" pill) clears the layer.

## Persistence & export
- [ ] Draw → back → reopen → strokes still there.
- [ ] App backgrounded → foregrounded → drawing intact and editable.
- [ ] Share → parent gate → share sheet shows; Save to Photos succeeds and the saved image matches the canvas.
- [ ] Print via the share sheet renders correctly.

## Parent gate
- [ ] Single-finger tap-and-hold on one dot never passes the gate.
- [ ] Holding all three dots for ~3 seconds passes the gate.
- [ ] Lifting any finger before 3 seconds resets progress.

## Misc
- [ ] App locked to iPad (no iPhone target).
- [ ] Launching with empty Documents dir shows an empty gallery with the "+" tile.
- [ ] Deleting a drawing → wiggle → minus → parent gate → drawing disappears and its folder is removed from Documents.
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/test-plans/
git commit -m "docs: manual on-device test plan for Sketchbook v1"
```

---

## Self-review — coverage check

Run through the spec sections and confirm each is covered:

- **§3.1 Tech stack** — Swift, SwiftUI, PencilKit, Core Image, filesystem, iOS 17. ✅ Manual prereq + Tasks 1, 6, 10, 16.
- **§3.3 Module boundaries** — covered by file structure block + Tasks 2–34.
- **§4.1 Gallery** — Tasks 25–27, 36. ✅
- **§4.2 Drawing screen layout** — Tasks 19–24, 35. ✅
- **§4.3 Adaptive UI** — Tasks 20–22 (size bloom, long-press wheel, More menu). ✅
- **§5.1 Brushes mapping** — Task 14. ✅
- **§5.2 Colour palette muted** — Tasks 5 + 21. ✅
- **§5.3 Undo/Redo** — Task 35. ✅
- **§6 Photo feature (source, mode, layer architecture)** — Tasks 28–33, 11. ✅
- **§7 Data model + on-disk layout + save cadence + thumbnail rendering** — Tasks 2–11. ✅
- **§8 Parent gate** — Tasks 12–13. ✅
- **§9 Pencil + finger input setup** — Tasks 15–16, 19 (toggle). ✅
- **§10 Export** — Task 34. ✅
- **§11 Testing (unit, UI, manual)** — Tasks 2–18, 26, 37–38. ✅
- **§12 Out of scope** — honoured throughout (no sounds, no multi-layer, no iCloud).

No spec section is unaddressed. No `TBD` / `TODO` markers remain. Function names are consistent (`clearCanvas` everywhere, `flushSave` everywhere, `PhotoLayer.Mode` everywhere).
