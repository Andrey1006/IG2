import SwiftUI

struct DrawStep: View {
    @ObservedObject var draft: Draft
    @StateObject private var sensor = ShakeSensor()
    @State private var spots: [CGPoint] = []
    @State private var held: Int?
    @State private var pull: CGSize = .zero
    @State private var spinFrom: Angle?
    @State private var wobble = 0.0
    @State private var reveal: Team?
    @State private var flip = 90.0

    private let bowl: CGFloat = 230
    private let ball: CGFloat = 34

    private var remaining: [Team] {
        let out = Set(draft.drawn.map(\.id))
        return draft.teams.filter { !out.contains($0.id) }
    }

    private var pot: [Team] {
        let seeded = remaining.filter(\.seeded)
        return seeded.isEmpty ? remaining : seeded
    }

    private var potName: String {
        if remaining.isEmpty { return "Bowl empty" }
        let anySeeded = draft.teams.contains(where: \.seeded)
        guard anySeeded else { return "\(remaining.count) balls left" }
        return pot.first?.seeded == true ? "Pot 1 · seeded · \(pot.count) left" : "Pot 2 · \(pot.count) left"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Masthead(kicker: potName, title: "The Draw")

                board

                revealCard

                bowlView
                    .frame(maxWidth: .infinity)

                controls

                if remaining.isEmpty && draft.canRehearse {
                    ChalkSwitch(
                        title: "Play out the first two rounds",
                        detail: "Fills them with sample results so you can look around. Wipe them later in Desk.",
                        isOn: $draft.sampleResults
                    )
                    .padding(18)
                    .flagCard()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .padding(.bottom, 10)
        }
        .onAppear {
            sensor.start()
            pour()
        }
        .onDisappear { sensor.stop() }
        .onChange(of: sensor.shakes) { _ in mix() }
        .onChange(of: pot.count) { _ in
            if spots.count != min(pot.count, 16) { pour() }
        }
    }

    @ViewBuilder
    private var board: some View {
        if draft.format == .groups {
            let g = max(draft.groupCount, 1)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(0..<g, id: \.self) { group in
                    let size = (draft.teams.count + g - 1 - group) / g
                    let members = draft.drawn.enumerated().filter { $0.offset % g == group }.map(\.element)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("GROUP \(Stage.letter(group))")
                            .font(.copy(11, .heavy))
                            .tracking(1.6)
                            .foregroundColor(Turf.floodlight)
                        ForEach(0..<size, id: \.self) { slot in
                            slotLine(slot < members.count ? members[slot] : nil)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Turf.pitch))
                }
            }
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 6) {
                ForEach(0..<draft.teams.count, id: \.self) { i in
                    HStack(spacing: 6) {
                        Text("\(i + 1)")
                            .font(.tally(12, .bold))
                            .foregroundColor(Turf.floodlight)
                            .frame(width: 22, alignment: .trailing)
                        slotLine(i < draft.drawn.count ? draft.drawn[i] : nil)
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Turf.pitch))
        }
    }

    private func slotLine(_ team: Team?) -> some View {
        HStack(spacing: 6) {
            if let team {
                Kit(index: team.kit, size: 12)
                Text(team.name)
                    .font(.copy(13, .bold))
                    .foregroundColor(Turf.chalk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if team.seeded { Text("⭐️").font(.system(size: 9)) }
            } else {
                Capsule()
                    .stroke(Turf.chalk.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(height: 16)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 22)
        .transition(.scale.combined(with: .opacity))
    }

    @ViewBuilder
    private var revealCard: some View {
        if let reveal {
            HStack(spacing: 14) {
                Kit(index: reveal.kit, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(placement(of: reveal))
                        .font(.copy(12, .heavy))
                        .tracking(1.4)
                        .foregroundColor(Turf.inkGold)
                    Text(reveal.name)
                        .font(.banner(24))
                        .foregroundColor(Turf.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer()
                Text(reveal.seeded ? "⭐️" : "🎉").font(.system(size: 28))
            }
            .padding(16)
            .flagCard(Turf.paper, radius: 18, notch: 22)
            .rotation3DEffect(.degrees(flip), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .opacity(flip > 80 ? 0 : 1)
        }
    }

    private func placement(of team: Team) -> String {
        guard let i = draft.drawn.firstIndex(where: { $0.id == team.id }) else { return "" }
        if draft.format == .groups {
            return "BALL \(i + 1) → GROUP \(Stage.letter(i % max(draft.groupCount, 1)))"
        }
        return draft.format == .knockout ? "SEED \(i + 1)" : "BALL \(i + 1)"
    }

    private var bowlView: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Turf.stripe, Turf.night], center: .center, startRadius: 10, endRadius: bowl / 2))
            Circle()
                .stroke(Turf.chalk.opacity(0.55), lineWidth: 2)
            Circle()
                .trim(from: 0.58, to: 0.92)
                .stroke(Turf.chalk.opacity(0.35), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .padding(10)
                .blur(radius: 1)

            if spots.isEmpty {
                VStack(spacing: 6) {
                    Art(art: .drawBowl, height: 120, medallion: true)
                    Text("All drawn")
                        .font(.copy(14, .bold))
                        .foregroundColor(Turf.haze)
                }
            }

            ForEach(Array(spots.enumerated()), id: \.offset) { i, p in
                capsule(highlight: held == i)
                    .offset(x: p.x * bowl / 2, y: p.y * bowl / 2)
                    .offset(held == i ? pull : .zero)
                    .zIndex(held == i ? 2 : 0)
                    .gesture(pullGesture(i))
            }
        }
        .frame(width: bowl, height: bowl)
        .rotationEffect(.degrees(wobble))
        .contentShape(Circle())
        .gesture(spinGesture)
        .overlay(alignment: .top) {
            Text(spots.isEmpty ? "" : "Drag a ball out ↑")
                .font(.copy(12, .heavy))
                .foregroundColor(Turf.haze)
                .offset(y: -22)
        }
        .padding(.top, 22)
    }

    private func capsule(highlight: Bool) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Turf.chalk, Turf.paperShade], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle()
                .trim(from: 0, to: 0.5)
                .fill(pot.first?.seeded == true ? Turf.floodlight : Turf.haze)
                .rotationEffect(.degrees(180))
            Circle()
                .fill(.white.opacity(0.7))
                .frame(width: ball * 0.26)
                .offset(x: -ball * 0.18, y: -ball * 0.18)
            Text("?")
                .font(.banner(13))
                .foregroundColor(Turf.ink.opacity(0.7))
        }
        .frame(width: ball, height: ball)
        .shadow(color: .black.opacity(0.35), radius: highlight ? 10 : 3, y: highlight ? 8 : 2)
        .scaleEffect(highlight ? 1.25 : 1)
        .animation(.spring(response: 0.3), value: highlight)
    }

    private func pullGesture(_ i: Int) -> some Gesture {
        DragGesture()
            .onChanged { g in
                if held != i {
                    held = i
                    Buzz.tick()
                }
                let wasOut = isOut(i, pull)
                pull = g.translation
                if isOut(i, pull) && !wasOut { Buzz.threshold() }
            }
            .onEnded { g in
                if isOut(i, g.translation) {
                    draw(spot: i)
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { pull = .zero }
                    held = nil
                }
            }
    }

    private func isOut(_ i: Int, _ t: CGSize) -> Bool {
        guard spots.indices.contains(i) else { return false }
        let x = spots[i].x * bowl / 2 + t.width
        let y = spots[i].y * bowl / 2 + t.height
        return (x * x + y * y).squareRoot() > bowl / 2 + ball * 0.3
    }

    private var spinGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { g in
                let c = CGPoint(x: bowl / 2, y: bowl / 2)
                let a = Angle(radians: atan2(g.location.y - c.y, g.location.x - c.x))
                if let from = spinFrom {
                    let delta = a.radians - from.radians
                    let cosd = cos(delta), sind = sin(delta)
                    spots = spots.map { CGPoint(x: $0.x * cosd - $0.y * sind, y: $0.x * sind + $0.y * cosd) }
                    if abs(delta) > 0.02 && Int(a.degrees) % 30 == 0 { Buzz.tick() }
                }
                spinFrom = a
            }
            .onEnded { _ in
                spinFrom = nil
                mix()
            }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            if !remaining.isEmpty {
                Button(sensor.available ? "📳 Shake · Mix" : "🌀 Mix") { mix() }
                    .buttonStyle(ChalkLineButton(compact: true))
            }
            Spacer()
            if remaining.isEmpty {
                Button("↺ Redo draw") {
                    withAnimation(.spring(response: 0.4)) {
                        draft.drawn.removeAll()
                        reveal = nil
                    }
                    pour()
                    Buzz.tick()
                }
                .buttonStyle(ChalkLineButton(compact: true))
            } else {
                Button("Draw the rest") {
                    var order: [Team] = []
                    order += remaining.filter(\.seeded).shuffled()
                    order += remaining.filter { !$0.seeded }.shuffled()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        draft.drawn += order
                        spots = []
                        reveal = order.last
                    }
                    flip = 0
                    Buzz.thud()
                }
                .buttonStyle(ChalkLineButton(tint: Turf.floodlight, compact: true))
            }
        }
    }

    private func scatter(_ n: Int) -> [CGPoint] {
        var out: [CGPoint] = []
        var tries = 0
        while out.count < n && tries < 2000 {
            tries += 1
            let r = 0.72 * CGFloat.random(in: 0...1).squareRoot()
            let a = CGFloat.random(in: 0..<(2 * .pi))
            let p = CGPoint(x: r * cos(a), y: r * sin(a))
            let clear = out.allSatisfy { hypot($0.x - p.x, $0.y - p.y) > (n > 12 ? 0.2 : 0.28) }
            if clear || tries > 1500 { out.append(p) }
        }
        return out
    }

    private func pour() {
        let n = min(pot.count, 16)
        spots = Array(repeating: CGPoint(x: 0, y: -0.9), count: n)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { spots = scatter(n) }
    }

    private func mix() {
        guard !spots.isEmpty else { return }
        Buzz.tick()
        withAnimation(.spring(response: 0.18, dampingFraction: 0.3)) { wobble = Double.random(in: -9...9) }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) { spots = scatter(spots.count) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { wobble = 0 }
        }
    }

    private func draw(spot i: Int) {
        guard let team = pot.randomElement() else { return }
        Buzz.thud()
        held = nil
        pull = .zero
        flip = 90
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            draft.drawn.append(team)
            reveal = team
            if spots.indices.contains(i) { spots.remove(at: i) }
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(0.05)) { flip = 0 }
        if pot.count > spots.count && spots.count < 16 {
            withAnimation(.spring(response: 0.5)) { spots += scatter(1) }
        }
    }
}
