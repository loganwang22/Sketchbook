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
