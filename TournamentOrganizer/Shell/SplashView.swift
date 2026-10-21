import SwiftUI

struct SplashView: View {
    var onFinish: () -> Void = {}

    @State private var seeded = false
    @State private var firstRound: CGFloat = 0
    @State private var secondRound: CGFloat = 0
    @State private var finalRun: CGFloat = 0
    @State private var goldRun: CGFloat = 0
    @State private var crowned = false
    @State private var ripple = false
    @State private var beams = false
    @State private var words = 0
    @State private var drift: CGFloat = 0
    @State private var clock: CGFloat = 0
    @State private var leaving = false

    private let board = CGSize(width: 320, height: 240)
    private let tagline = ["Draw it.", "Play it.", "Crown it."]
    private let seeds: [CGFloat] = [0.125, 0.375, 0.625, 0.875]

    var body: some View {
        ZStack {
            Mown(drift: drift)
                .ignoresSafeArea()

            RadialGradient(
                colors: [Turf.floodlight.opacity(crowned ? 0.16 : 0), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 340
            )
            .ignoresSafeArea()

            beamPair

            VStack(spacing: 48) {
                bracket
                taglineRow
            }
            .scaleEffect(leaving ? 1.14 : 1)
            .opacity(leaving ? 0 : 1)
            .blur(radius: leaving ? 8 : 0)

            VStack {
                Spacer()
                progress
            }
        }
        .task { await play() }
    }

    private var beamPair: some View {
        GeometryReader { geo in
            ZStack {
                beam(height: geo.size.height)
                    .rotationEffect(.degrees(beams ? -32 : -58), anchor: .top)
                    .position(x: 0, y: geo.size.height * 0.45)
                beam(height: geo.size.height)
                    .rotationEffect(.degrees(beams ? 32 : 58), anchor: .top)
                    .position(x: geo.size.width, y: geo.size.height * 0.45)
            }
            .opacity(beams ? 1 : 0)
            .opacity(leaving ? 0 : 1)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func beam(height: CGFloat) -> some View {
        Floodbeam()
            .fill(
                LinearGradient(
                    colors: [Turf.floodlight.opacity(0.32), Turf.floodlight.opacity(0.06), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 240, height: height * 0.9)
            .blendMode(.plusLighter)
    }

    private var bracket: some View {
        ZStack {
            ForEach([false, true], id: \.self) { mirrored in
                ForEach(seeds.indices, id: \.self) { i in
                    let merge: CGFloat = i < 2 ? 0.25 : 0.75
                    Chalkline(points: side([
                        CGPoint(x: 0.05, y: seeds[i]),
                        CGPoint(x: 0.17, y: seeds[i]),
                        CGPoint(x: 0.17, y: merge)
                    ], mirrored))
                    .trim(from: 0, to: firstRound)
                    .stroke(Turf.chalk.opacity(0.55), style: chalk)
                }

                ForEach([0.25, 0.75] as [CGFloat], id: \.self) { y in
                    Chalkline(points: side([
                        CGPoint(x: 0.17, y: y),
                        CGPoint(x: 0.31, y: y),
                        CGPoint(x: 0.31, y: 0.5)
                    ], mirrored))
                    .trim(from: 0, to: secondRound)
                    .stroke(Turf.chalk.opacity(0.55), style: chalk)
                }

                Chalkline(points: side([
                    CGPoint(x: 0.31, y: 0.5),
                    CGPoint(x: 0.4, y: 0.5)
                ], mirrored))
                .trim(from: 0, to: finalRun)
                .stroke(Turf.chalk.opacity(0.55), style: chalk)

                ForEach(seeds.indices, id: \.self) { i in
                    let index = mirrored ? i + seeds.count : i
                    Circle()
                        .fill(Turf.kit(index))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Turf.night, lineWidth: 2))
                        .overlay(
                            Circle()
                                .stroke(Turf.floodlight, lineWidth: 2)
                                .padding(-4)
                                .opacity(index == 1 && goldRun > 0 ? 1 : 0)
                        )
                        .scaleEffect(seeded ? 1 : 0.01)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(Double(index) * 0.04), value: seeded)
                        .position(at(CGPoint(x: mirrored ? 0.975 : 0.025, y: seeds[i])))
                }
            }

            Chalkline(points: [
                CGPoint(x: 0.05, y: 0.375),
                CGPoint(x: 0.17, y: 0.375),
                CGPoint(x: 0.17, y: 0.25),
                CGPoint(x: 0.31, y: 0.25),
                CGPoint(x: 0.31, y: 0.5),
                CGPoint(x: 0.4, y: 0.5)
            ])
            .trim(from: 0, to: goldRun)
            .stroke(Turf.floodlight, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
            .shadow(color: Turf.floodlight.opacity(0.8), radius: 6)

            badge
                .position(at(CGPoint(x: 0.5, y: 0.5)))
        }
        .frame(width: board.width, height: board.height)
    }

    private var badge: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Turf.floodlight.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 64, height: 64)
                    .scaleEffect(ripple ? 2.8 : 1)
                    .opacity(ripple ? 0 : (crowned ? 0.9 : 0))
                    .animation(
                        .easeOut(duration: 1.4).repeatForever(autoreverses: false).delay(Double(i) * 0.45),
                        value: ripple
                    )
            }

            Circle()
                .fill(Turf.pitch)
                .frame(width: 64, height: 64)
                .overlay(Circle().stroke(Turf.floodlight, lineWidth: 2.5))
                .shadow(color: Turf.floodlight.opacity(crowned ? 0.7 : 0), radius: 20)

            Image(systemName: "trophy.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Turf.floodlight)
                .scaleEffect(crowned ? 1 : 0.4)
                .animation(.spring(response: 0.35, dampingFraction: 0.4).delay(0.12), value: crowned)
        }
        .scaleEffect(crowned ? 1 : 0.2)
        .rotationEffect(.degrees(crowned ? 0 : -120))
        .opacity(crowned ? 1 : 0)
    }

    private var taglineRow: some View {
        HStack(spacing: 10) {
            ForEach(tagline.indices, id: \.self) { i in
                Text(tagline[i])
                    .font(.copy(19, .bold))
                    .tracking(0.6)
                    .foregroundStyle(i == tagline.count - 1 ? Turf.floodlight : Turf.chalk)
                    .opacity(words > i ? 1 : 0)
                    .offset(y: words > i ? 0 : 14)
                    .blur(radius: words > i ? 0 : 4)
            }
        }
        .frame(height: 28)
    }

    private var progress: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Turf.chalk.opacity(0.1))
            Capsule()
                .fill(Turf.floodlight)
                .frame(width: 120 * clock)
        }
        .frame(width: 120, height: 3)
        .opacity(leaving ? 0 : 1)
        .padding(.bottom, 36)
    }

    private var chalk: StrokeStyle {
        StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
    }

    private func side(_ points: [CGPoint], _ mirrored: Bool) -> [CGPoint] {
        mirrored ? points.map { CGPoint(x: 1 - $0.x, y: $0.y) } : points
    }

    private func at(_ unit: CGPoint) -> CGPoint {
        CGPoint(x: unit.x * board.width, y: unit.y * board.height)
    }

    private func play() async {
        let start = ContinuousClock.now

        func wait(until seconds: Double) async {
            try? await Task.sleep(until: start + .milliseconds(Int(seconds * 1000)), clock: .continuous)
        }

        withAnimation(.linear(duration: 3)) {
            drift = 80
            clock = 1
        }
        withAnimation(.easeOut(duration: 1.1)) { beams = true }
        seeded = true

        await wait(until: 0.3)
        withAnimation(.easeInOut(duration: 0.5)) { firstRound = 1 }

        await wait(until: 0.75)
        withAnimation(.easeInOut(duration: 0.45)) { secondRound = 1 }

        await wait(until: 1.15)
        withAnimation(.easeOut(duration: 0.25)) { finalRun = 1 }

        await wait(until: 1.35)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { crowned = true }
        ripple = true
        Buzz.thud()

        await wait(until: 1.45)
        withAnimation(.easeInOut(duration: 0.6)) { goldRun = 1 }

        for i in tagline.indices {
            await wait(until: 1.75 + Double(i) * 0.18)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { words = i + 1 }
        }

        await wait(until: 2.6)
        withAnimation(.easeIn(duration: 0.4)) { leaving = true }

        await wait(until: 3)
        onFinish()
    }
}

struct Chalkline: Shape {
    var points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: scaled(first, in: rect))
        for point in points.dropFirst() {
            p.addLine(to: scaled(point, in: rect))
        }
        return p
    }

    private func scaled(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
    }
}

struct Floodbeam: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX - 6, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX + 6, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    SplashView()
        .preferredColorScheme(.dark)
}
