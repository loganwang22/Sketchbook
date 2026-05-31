import SwiftUI

// `navigationDestination(item:)` requires Hashable. Drawing is Identifiable
// with a UUID id, so id-based hashing is correct and unique.
extension Drawing: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

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
            .sheet(isPresented: deleteGateBinding) {
                ParentGateSheet(
                    onPass: { try? viewModel.confirmDelete() },
                    onCancel: { viewModel.cancelDelete() }
                )
            }
        }
    }

    private var deleteGateBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingDeleteId != nil },
            set: { newValue in
                if !newValue { viewModel.cancelDelete() }
            }
        )
    }

    private func startNew() {
        guard let d = try? viewModel.createNew() else { return }
        openedDrawing = d
    }
}
