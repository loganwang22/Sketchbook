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
    let hasPhoto: Bool
    let photoHidden: Bool
    let onTogglePhoto: () -> Void
    let onRemovePhoto: () -> Void

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
            if hasPhoto {
                chipButton(systemName: photoHidden ? "eye.slash" : "eye", action: onTogglePhoto)
                    .accessibilityLabel(photoHidden ? "Show picture" : "Hide picture")
            }
            Menu {
                Button { onShare() } label: { Label("Share", systemImage: "square.and.arrow.up") }
                Button { onBackgroundColor() } label: { Label("Background", systemImage: "rectangle.fill") }
                Divider()
                Button(role: .destructive) { onClear() } label: { Label("Clear canvas", systemImage: "trash") }
                if hasPhoto {
                    Button(role: .destructive) { onRemovePhoto() } label: {
                        Label("Remove picture", systemImage: "photo.badge.minus")
                    }
                }
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
           onToggleFingerDrawing: {}, fingerDrawingOn: false,
           hasPhoto: true, photoHidden: false,
           onTogglePhoto: {}, onRemovePhoto: {})
}
