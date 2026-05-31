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
