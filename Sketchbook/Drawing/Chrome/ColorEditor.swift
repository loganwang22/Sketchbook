import SwiftUI

/// A single-panel colour picker: a hue × lightness spectrum field plus draggable
/// H / S / L bars. No tabs, no preset swatches. Edits the bound colour live.
struct ColorEditor: View {
    @Binding var color: ColorRGBA
    let onFinish: () -> Void

    @State private var h = 0.0   // hue        0...1
    @State private var s = 1.0   // saturation 0...1
    @State private var l = 0.5   // lightness  0...1
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 22) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorRGBA(h: h, s: s, l: l).swiftUIColor)
                    .frame(width: 64, height: 36)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.15)))
                Spacer()
                Button("Done", action: onFinish)
                    .font(.headline.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
            }

            SpectrumField(hue: $h, lightness: $l)
                .frame(height: 220)

            VStack(spacing: 16) {
                sliderRow("Hue", GradientSlider(value: $h, gradient: hueGradient))
                sliderRow("Saturation", GradientSlider(value: $s, gradient: satGradient))
                sliderRow("Lightness", GradientSlider(value: $l, gradient: lightGradient))
            }
        }
        .padding(24)
        .onAppear {
            let c = color.hsl; h = c.h; s = c.s; l = c.l
            // Defer "loaded" so the state writes above don't fire a redundant commit
            // (which would mark the drawing dirty just for opening the picker).
            DispatchQueue.main.async { loaded = true }
        }
        .onChange(of: h) { _, _ in commit() }
        .onChange(of: s) { _, _ in commit() }
        .onChange(of: l) { _, _ in commit() }
    }

    private func commit() {
        guard loaded else { return }
        color = ColorRGBA(h: h, s: s, l: l)
    }

    private func sliderRow(_ title: String, _ slider: GradientSlider) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            slider
        }
    }

    private var hueGradient: LinearGradient {
        LinearGradient(colors: stride(from: 0.0, through: 1.0, by: 1.0 / 24).map {
            Color(hue: $0, saturation: 1, brightness: 1)
        }, startPoint: .leading, endPoint: .trailing)
    }
    private var satGradient: LinearGradient {
        LinearGradient(colors: [ColorRGBA(h: h, s: 0, l: l).swiftUIColor,
                                ColorRGBA(h: h, s: 1, l: l).swiftUIColor],
                       startPoint: .leading, endPoint: .trailing)
    }
    private var lightGradient: LinearGradient {
        LinearGradient(colors: [.black,
                                ColorRGBA(h: h, s: s, l: 0.5).swiftUIColor,
                                .white],
                       startPoint: .leading, endPoint: .trailing)
    }
}

/// 2D spectrum: hue across X, lightness up the Y (white top → black bottom), drawn at
/// full saturation. Dragging moves the crosshair and sets hue + lightness.
private struct SpectrumField: View {
    @Binding var hue: Double
    @Binding var lightness: Double

    private var rainbow: [Color] {
        stride(from: 0.0, through: 1.0, by: 1.0 / 24).map { Color(hue: $0, saturation: 1, brightness: 1) }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(colors: rainbow, startPoint: .leading, endPoint: .trailing)
                LinearGradient(stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white.opacity(0), location: 0.5),
                    .init(color: .black.opacity(0), location: 0.5),
                    .init(color: .black, location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                Circle()
                    .stroke(.white, lineWidth: 3)
                    .overlay(Circle().stroke(.black.opacity(0.35), lineWidth: 1))
                    .frame(width: 26, height: 26)
                    .shadow(radius: 2)
                    .position(x: hue * w, y: (1 - lightness) * h)
            )
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                hue = min(max(v.location.x / w, 0), 1)
                lightness = min(max(1 - v.location.y / h, 0), 1)
            })
        }
    }
}

/// A draggable bar filled with a gradient; `value` is 0...1 along its width.
private struct GradientSlider: View {
    @Binding var value: Double
    let gradient: LinearGradient

    private let thumb: CGFloat = 26

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let clamped = min(max(value, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(gradient)
                Capsule().stroke(.black.opacity(0.1))
                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(.black.opacity(0.2)))
                    .frame(width: thumb, height: thumb)
                    .shadow(radius: 1.5)
                    .offset(x: clamped * (w - thumb))
            }
            .frame(height: thumb)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                value = min(max((v.location.x - thumb / 2) / (w - thumb), 0), 1)
            })
        }
        .frame(height: thumb)
    }
}

#Preview {
    @Previewable @State var color = KidPalette.colors[3].color
    return ColorEditor(color: $color, onFinish: {})
}
