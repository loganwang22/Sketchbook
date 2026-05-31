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
