import SwiftUI

struct GoalColumn: View {
    let t: Tournament
    let f: Fixture
    let side: Side
    let onGoal: () -> Void

    @State private var lift: CGFloat = 0
    @State private var armed = false
    private let trigger: CGFloat = 70

    var body: some View {
        let team = t.team(at: f.seat(side))
        let kit = Turf.kit(team?.kit ?? 10)

        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Kit(index: team?.kit ?? 10, size: 14, crest: team?.crest)
                Text(team?.name ?? "?")
                    .font(.copy(14, .heavy))
                    .foregroundColor(Turf.chalk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text("\(f.goals(side))")
                .font(.scoreboard(84))
                .foregroundColor(armed ? Turf.floodlight : Turf.chalk)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: f.goals(side))
            Text(armed ? "Let go — GOAL!" : "⇡ swipe up to score")
                .font(.copy(11, .heavy))
                .foregroundColor(armed ? Turf.floodlight : Turf.haze)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Turf.pitch)
                Net()
                    .stroke(Turf.chalk.opacity(armed ? 0.35 : 0.1), lineWidth: 1)
                    .frame(height: 46)
                    .padding(.horizontal, 26)
                Rectangle()
                    .fill(kit)
                    .frame(height: 5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(armed ? Turf.floodlight : Turf.chalk.opacity(0.06), lineWidth: armed ? 2 : 1)
        )
        .offset(y: lift)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { g in
                    lift = max(min(g.translation.height * 0.35, 8), -40)
                    let hot = g.translation.height < -trigger
                    if hot != armed {
                        armed = hot
                        if hot { Buzz.threshold() }
                    }
                }
                .onEnded { g in
                    let scored = g.translation.height < -trigger
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                        lift = 0
                        armed = false
                    }
                    if scored { onGoal() }
                }
        )
    }
}

private struct Net: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        let cols = 8
        for i in 1..<cols {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(cols)
            p.move(to: CGPoint(x: x, y: rect.minY))
            p.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        for j in 1..<3 {
            let y = rect.minY + rect.height * CGFloat(j) / 3
            p.move(to: CGPoint(x: rect.minX, y: y))
            p.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return p
    }
}

struct RosterColumn: View {
    let t: Tournament
    let f: Fixture
    let side: Side
    let barred: Set<UUID>
    let hover: UUID?
    let carrying: Incident.Kind?
    let onAdd: () -> Void

    var body: some View {
        let players = t.team(at: f.seat(side))?.players ?? []
        ScrollView(showsIndicators: false) {
            VStack(spacing: 5) {
                ForEach(players) { p in
                    chip(p)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(key: ChipFrames.self, value: [p.id: geo.frame(in: .named("board"))])
                            }
                        )
                }
                Button(action: onAdd) {
                    Label("Player", systemImage: "plus")
                        .font(.copy(12, .heavy))
                        .foregroundColor(Turf.haze)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .overlay(Capsule().stroke(Turf.chalk.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
                .buttonStyle(Squash())
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func chip(_ p: Player) -> some View {
        let mine = f.incidents.filter { $0.player == p.id }
        let goals = mine.filter { $0.kind == .goal }.count
        let yellows = mine.filter { $0.kind == .yellow }.count
        let red = mine.contains { $0.kind == .red } || yellows >= 2
        let out = barred.contains(p.id)
        let hot = hover == p.id
        let tint = carrying == .red ? Turf.dismissal : Turf.booking

        return HStack(spacing: 5) {
            Text(p.number.map { "\($0)" } ?? "·")
                .font(.tally(11, .bold))
                .foregroundColor(hot ? Turf.ink : Turf.haze)
                .frame(width: 20)
            Text(p.shortName)
                .font(.copy(13, .bold))
                .foregroundColor(hot ? Turf.ink : (out ? Turf.haze.opacity(0.5) : Turf.chalk))
                .strikethrough(out && !red)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if goals > 0 {
                Text(goals > 1 ? "⚽️×\(goals)" : "⚽️").font(.system(size: 10))
            }
            if red {
                Text("🟥").font(.system(size: 10))
            } else if yellows == 1 {
                Text("🟨").font(.system(size: 10))
            } else if out {
                Text("🚫").font(.system(size: 10))
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 32)
        .background(Capsule().fill(hot ? (out ? Turf.haze : tint) : Turf.pitch))
        .scaleEffect(hot ? 1.05 : 1)
        .animation(.spring(response: 0.2), value: hot)
    }
}

struct CardFace: View {
    let kind: Incident.Kind

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(kind == .red ? Turf.dismissal : Turf.booking)
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(.white.opacity(0.35), lineWidth: 1)
                    .padding(4)
            )
            .shadow(color: .black.opacity(0.4), radius: 8, y: 5)
    }
}

struct PocketCard: View {
    let kind: Incident.Kind
    let hidden: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                CardFace(kind: kind)
                    .frame(width: 40, height: 56)
                    .rotationEffect(.degrees(kind == .red ? 8 : -8))
                    .offset(y: hidden ? 30 : 0)
                    .opacity(hidden ? 0 : 1)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Turf.night)
                    .frame(width: 64, height: 26)
                    .offset(y: 26)
            }
            .frame(height: 64)
            .clipped()
            Text(kind == .red ? "drag red" : "drag yellow")
                .font(.copy(10, .heavy))
                .foregroundColor(Turf.haze)
        }
        .frame(width: 80)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.3), value: hidden)
    }
}

struct WhistleHold: View {
    let goldenGoal: Bool
    let onBlow: () -> Void

    @State private var ring: CGFloat = 0
    @State private var pressing = false
    private let hold = 1.1

    var body: some View {
        ZStack {
            Capsule()
                .fill(Turf.pitch)
            GeometryReader { geo in
                Capsule()
                    .fill(Turf.floodlight)
                    .frame(width: geo.size.width * ring)
            }
            .clipShape(Capsule())
            HStack(spacing: 8) {
                Text("📣")
                    .font(.system(size: 22))
                    .rotationEffect(.degrees(pressing ? -14 : 0))
                VStack(alignment: .leading, spacing: 0) {
                    Text(pressing ? "Keep holding…" : "Hold for full time")
                        .font(.copy(14, .heavy))
                    Text(goldenGoal ? "only if level ends it" : "ends the match")
                        .font(.copy(10, .bold))
                        .opacity(0.7)
                }
                .foregroundColor(ring > 0.5 ? Turf.ink : Turf.chalk)
            }
        }
        .frame(height: 62)
        .frame(maxWidth: .infinity)
        .overlay(Capsule().stroke(Turf.floodlight.opacity(0.5), lineWidth: 1.2))
        .scaleEffect(pressing ? 0.97 : 1)
        .onLongPressGesture(minimumDuration: hold, maximumDistance: 40) {
            Buzz.thud()
            onBlow()
            withAnimation(.easeOut(duration: 0.25)) { ring = 0 }
        } onPressingChanged: { down in
            pressing = down
            if down {
                Buzz.tick()
                withAnimation(.linear(duration: hold)) { ring = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + hold * 0.55) {
                    if pressing { Buzz.threshold() }
                }
            } else {
                withAnimation(.easeOut(duration: 0.25)) { ring = 0 }
            }
        }
    }
}

struct ScorerPanel: View {
    let t: Tournament
    let f: Fixture
    let panel: Panel
    let barred: (Side) -> Set<UUID>
    let onClose: () -> Void

    @EnvironmentObject private var club: Clubhouse
    @State private var ownGoal = false
    @State private var scorer: UUID?
    @State private var newName = ""
    @State private var number = ""

    private var side: Side {
        switch panel {
        case .scorer(let s, _): return s
        case .newPlayer(let s): return s
        }
    }

    private var roster: Side { ownGoal ? side.other : side }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(title)
                        .font(.banner(20))
                        .foregroundColor(Turf.chalk)
                    Spacer()
                    Button(scoring ? "Skip" : "Close") {
                        if scorer != nil { finish(nil) } else { onClose() }
                    }
                    .buttonStyle(ChalkLineButton(compact: true))
                }
                if let scorer {
                    ScrollView(showsIndicators: false) {
                        PlayerChips(
                            players: (t.team(at: f.seat(side))?.players ?? []).filter { $0.id != scorer },
                            selected: Binding(get: { nil }, set: { finish($0) }),
                            barred: barred(side)
                        )
                    }
                    .frame(maxHeight: 190)
                } else if scoring {
                    HStack(spacing: 8) {
                        Button {
                            ownGoal = false
                            Buzz.tick()
                        } label: { Chip(text: "⚽️ \(t.team(at: f.seat(side))?.code ?? "")", on: !ownGoal) }
                        Button {
                            ownGoal = true
                            Buzz.tick()
                        } label: { Chip(text: "🥅 Own goal by \(t.team(at: f.seat(side.other))?.code ?? "")", on: ownGoal, tint: Turf.booking) }
                    }
                    .buttonStyle(Squash())

                    ScrollView(showsIndicators: false) {
                        PlayerChips(
                            players: t.team(at: f.seat(roster))?.players ?? [],
                            selected: Binding(get: { nil }, set: { pick($0) }),
                            barred: barred(roster)
                        )
                    }
                    .frame(maxHeight: 190)
                }
                HStack(spacing: 8) {
                    ChalkField(placeholder: "#", text: $number, size: 15, keyboard: .numberPad)
                        .frame(width: 58)
                    ChalkField(placeholder: "\(scorer == nil ? "New player" : "New assist") for \(t.team(at: f.seat(roster))?.code ?? "")", text: $newName, size: 15)
                    Button("Add") { add() }
                        .buttonStyle(ChalkLineButton(tint: Turf.floodlight, compact: true))
                }
            }
            .padding(20)
            .padding(.bottom, 80)
            .background(
                CornerFlag(radius: 28, notch: 36)
                    .fill(Turf.night)
                    .shadow(color: .black.opacity(0.5), radius: 20, y: -6)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    private var scoring: Bool {
        if case .scorer = panel { return true }
        return false
    }

    private var title: String {
        if scorer != nil { return "Who set it up?" }
        if scoring { return ownGoal ? "Who put it in their own net?" : "Who scored?" }
        return "Add to \(t.team(at: f.seat(side))?.name ?? "team")"
    }

    private func pick(_ player: UUID?) {
        guard case .scorer(let s, let incidentID) = panel,
              var incident = f.incidents.first(where: { $0.id == incidentID }) else {
            onClose()
            return
        }
        incident.player = player
        incident.kind = ownGoal ? .ownGoal : .goal
        incident.side = ownGoal ? s.other : s
        club.amend(incident, in: f.id)
        if let player, !ownGoal {
            Buzz.tick()
            withAnimation(.spring(response: 0.3)) { scorer = player }
            return
        }
        Buzz.success()
        onClose()
    }

    private func finish(_ assist: UUID?) {
        guard case .scorer(_, let incidentID) = panel,
              var incident = club.tournament?.fixture(f.id)?.incidents.first(where: { $0.id == incidentID }) else {
            onClose()
            return
        }
        incident.assist = assist
        club.amend(incident, in: f.id)
        Buzz.success()
        onClose()
    }

    private func add() {
        guard let team = t.team(at: f.seat(roster)),
              let p = club.addPlayer(newName, number: Int(number), to: team.id) else {
            Buzz.deny()
            return
        }
        newName = ""
        number = ""
        if scorer != nil {
            finish(p.id)
        } else if scoring {
            pick(p.id)
        } else {
            Buzz.tick()
            onClose()
        }
    }
}
