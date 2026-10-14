import SwiftUI

struct ChipFrames: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

enum Panel: Identifiable {
    case scorer(Side, UUID)
    case newPlayer(Side)

    var id: String {
        switch self {
        case .scorer(let s, let i): return "s\(s.rawValue)\(i)"
        case .newPlayer(let s): return "n\(s.rawValue)"
        }
    }
}

struct RefereeBoard: View {
    let t: Tournament
    let f: Fixture
    let onFinished: (Fixture) -> Void

    @EnvironmentObject private var club: Clubhouse
    @EnvironmentObject private var dugout: Dugout
    @State private var panel: Panel?
    @State private var frames: [UUID: CGRect] = [:]
    @State private var carrying: Incident.Kind?
    @State private var carryPoint: CGPoint = .zero
    @State private var hover: UUID?
    @State private var shootout = false
    @State private var flights: [Flight] = []

    struct Flight: Identifiable {
        let id = UUID()
        let side: Side
    }

    private func barred(_ side: Side) -> Set<UUID> {
        let off = f.incidents.filter { $0.side == side && $0.kind.isCard }
        let sent = Set(off.compactMap(\.player).filter { p in
            off.contains { $0.player == p && $0.kind == .red } || off.filter { $0.player == p && $0.kind == .yellow }.count >= 2
        })
        return t.unavailable(in: f, side: side).union(sent)
    }

    var body: some View {
        VStack(spacing: 10) {
            clockRow
            if f.goldenGoal {
                Text("✨ Golden goal — next goal wins")
                    .font(.copy(13, .heavy))
                    .foregroundColor(Turf.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(Capsule().fill(Turf.floodlight))
            }
            lastLine
            HStack(spacing: 10) {
                GoalColumn(t: t, f: f, side: .home) { goal(.home) }
                GoalColumn(t: t, f: f, side: .away) { goal(.away) }
            }
            .frame(height: 158)
            .overlay(flightLayer)

            HStack(alignment: .top, spacing: 10) {
                RosterColumn(t: t, f: f, side: .home, barred: barred(.home), hover: hover, carrying: carrying) { panel = .newPlayer(.home) }
                RosterColumn(t: t, f: f, side: .away, barred: barred(.away), hover: hover, carrying: carrying) { panel = .newPlayer(.away) }
            }
            .frame(maxHeight: .infinity)

            HStack(alignment: .center, spacing: 12) {
                PocketCard(kind: .yellow, hidden: carrying == .yellow)
                    .gesture(carry(.yellow))
                WhistleHold(goldenGoal: f.goldenGoal) { fullTime() }
                PocketCard(kind: .red, hidden: carrying == .red)
                    .gesture(carry(.red))
            }
            .frame(height: 96)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 82)
        .coordinateSpace(name: "board")
        .onPreferenceChange(ChipFrames.self) { frames = $0 }
        .overlay {
            if let carrying {
                CardFace(kind: carrying)
                    .frame(width: 48, height: 66)
                    .rotationEffect(.degrees(hover == nil ? -8 : 6))
                    .scaleEffect(hover == nil ? 1 : 1.15)
                    .position(carryPoint)
                    .allowsHitTesting(false)
                    .animation(.spring(response: 0.2), value: hover)
            }
        }
        .overlay {
            if let panel {
                ScorerPanel(t: club.tournament ?? t, f: club.tournament?.fixture(f.id) ?? f, panel: panel, barred: barred) { self.panel = nil }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.85), value: panel?.id)
        .sheet(isPresented: $shootout) {
            ShootoutSheet(t: t, f: f) { s in
                club.fullTime(f.id, shootout: s)
                if let done = club.tournament?.fixture(f.id) { onFinished(done) }
            }
        }
    }

    private var clockRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(f.stage.title.uppercased())
                    .font(.copy(11, .heavy))
                    .tracking(1.4)
                    .foregroundColor(Turf.floodlight)
                Text("Pitch \(Stage.pitchName(f.pitch)) · \(t.matchMinutes)′ match")
                    .font(.copy(12, .semibold))
                    .foregroundColor(Turf.haze)
            }
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let s = f.clock.elapsed(at: ctx.date)
                Text(Clockface.stopwatch(s))
                    .font(.scoreboard(38))
                    .foregroundColor(s >= TimeInterval(t.matchMinutes * 60) ? Turf.booking : Turf.chalk)
                    .opacity(f.clock.running ? 1 : 0.55)
            }
            Button {
                club.editFixture(f.id) { fx in
                    if fx.clock.running { fx.clock.stop() } else { fx.clock.start() }
                }
                Buzz.tick()
            } label: {
                Image(systemName: f.clock.running ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(Turf.ink)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Turf.chalk))
            }
            .buttonStyle(Squash())
            Button {
                dugout.path(.whistle).wrappedValue.append(.fixture(f.id))
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Turf.chalk)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Turf.pitch))
            }
            .buttonStyle(Squash())
        }
    }

    @ViewBuilder
    private var lastLine: some View {
        if let last = f.incidents.max(by: { $0.minute < $1.minute }) {
            let who = last.player.flatMap { t.roster(of: $0)?.0.shortName } ?? "Unknown"
            HStack(spacing: 8) {
                Text("\(last.minute)′ \(last.kind.emoji) \(who)")
                    .font(.copy(13, .bold))
                    .foregroundColor(Turf.chalk)
                    .lineLimit(1)
                Text(t.team(at: f.seat(last.side))?.code ?? "")
                    .font(.copy(11, .heavy))
                    .foregroundColor(Turf.haze)
                Spacer()
                Button("Undo") {
                    club.strike(last.id, in: f.id)
                    Buzz.tick()
                }
                .font(.copy(12, .heavy))
                .foregroundColor(Turf.floodlight)
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Capsule().fill(Turf.night.opacity(0.75)))
        }
    }

    private var flightLayer: some View {
        GeometryReader { geo in
            ForEach(flights) { flight in
                BallFlight()
                    .position(x: geo.size.width * (flight.side == .home ? 0.25 : 0.75), y: geo.size.height * 0.55)
            }
        }
        .allowsHitTesting(false)
    }

    private func now() -> Int {
        max(1, (club.tournament?.fixture(f.id)?.clock ?? f.clock).minute(at: .now))
    }

    private func goal(_ side: Side) {
        Buzz.thud()
        let flight = Flight(side: side)
        flights.append(flight)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            flights.removeAll { $0.id == flight.id }
        }
        let incident = Incident(kind: .goal, minute: now(), side: side, player: nil)
        if club.record(incident, in: f.id) {
            Buzz.success()
            if let done = club.tournament?.fixture(f.id) { onFinished(done) }
            return
        }
        panel = .scorer(side, incident.id)
    }

    private func carry(_ kind: Incident.Kind) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("board"))
            .onChanged { g in
                if carrying == nil {
                    carrying = kind
                    Buzz.tick()
                }
                carryPoint = CGPoint(x: g.location.x, y: g.location.y - 30)
                let over = frames.first { $0.value.insetBy(dx: -4, dy: -6).contains(carryPoint) }?.key
                if over != hover {
                    hover = over
                    if over != nil { Buzz.tick() }
                }
            }
            .onEnded { _ in
                defer {
                    withAnimation(.spring(response: 0.3)) {
                        carrying = nil
                        hover = nil
                    }
                }
                guard let target = hover,
                      let side = Side.allCases.first(where: { s in t.team(at: f.seat(s))?.players.contains { $0.id == target } == true }) else { return }
                if barred(side).contains(target) {
                    Buzz.deny()
                    return
                }
                club.record(Incident(kind: kind, minute: now(), side: side, player: target), in: f.id)
                Buzz.thud()
            }
    }

    private func fullTime() {
        guard let live = club.tournament?.fixture(f.id) else { return }
        if live.stage.isKnockout && live.isTied {
            if t.rules.decider == .penalties {
                Buzz.threshold()
                shootout = true
            } else {
                club.editFixture(f.id) { $0.goldenGoal = true }
                Buzz.deny()
            }
            return
        }
        club.fullTime(f.id)
        Buzz.success()
        if let done = club.tournament?.fixture(f.id) { onFinished(done) }
    }
}

private struct BallFlight: View {
    @State private var gone = false

    var body: some View {
        Text("⚽️")
            .font(.system(size: 44))
            .scaleEffect(gone ? 0.4 : 1.4)
            .rotationEffect(.degrees(gone ? 540 : 0))
            .offset(y: gone ? -150 : 0)
            .opacity(gone ? 0 : 1)
            .onAppear {
                withAnimation(.easeIn(duration: 0.9)) { gone = true }
            }
    }
}
