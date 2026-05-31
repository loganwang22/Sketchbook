import Foundation

struct ParentGateGesture {
    enum Dot: Hashable { case left, middle, right }

    private let requiredDuration: TimeInterval
    private let now: () -> TimeInterval
    private var down: Set<Dot> = []
    private var allDownSince: TimeInterval?

    init(requiredDuration: TimeInterval = 3.0,
         now: @escaping () -> TimeInterval = { Date().timeIntervalSinceReferenceDate }) {
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
