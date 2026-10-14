import SwiftUI

struct FloodlitButton: ButtonStyle {
    var fill = Turf.floodlight
    var text = Turf.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.banner(17))
            .tracking(0.6)
            .foregroundColor(text)
            .padding(.horizontal, 22)
            .frame(minHeight: 54)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(fill)
                    .shadow(color: fill.opacity(configuration.isPressed ? 0.15 : 0.45), radius: configuration.isPressed ? 4 : 14, y: configuration.isPressed ? 1 : 6)
            )
            .overlay(ChalkDust(active: configuration.isPressed))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct ChalkLineButton: ButtonStyle {
    var tint = Turf.chalk
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.copy(compact ? 14 : 16, .bold))
            .foregroundColor(tint)
            .padding(.horizontal, compact ? 14 : 20)
            .frame(minHeight: compact ? 36 : 50)
            .background(Capsule().fill(tint.opacity(configuration.isPressed ? 0.16 : 0.06)))
            .overlay(Capsule().stroke(tint.opacity(0.55), style: StrokeStyle(lineWidth: 1.4, dash: [5, 4])))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct Squash: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? 0.04 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

private struct ChalkDust: View {
    let active: Bool
    private let specks: [(CGFloat, CGFloat, CGFloat)] = [(-0.42, -0.6, 3), (0.38, -0.7, 2.5), (0.47, 0.55, 3.5), (-0.3, 0.75, 2), (0.05, -0.85, 2)]

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<specks.count, id: \.self) { i in
                let s = specks[i]
                Circle()
                    .fill(Turf.chalk.opacity(active ? 0.7 : 0))
                    .frame(width: s.2, height: s.2)
                    .position(
                        x: geo.size.width / 2 + s.0 * geo.size.width * (active ? 1.05 : 0.8),
                        y: geo.size.height / 2 + s.1 * geo.size.height * (active ? 1.1 : 0.6)
                    )
            }
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.35), value: active)
    }
}
