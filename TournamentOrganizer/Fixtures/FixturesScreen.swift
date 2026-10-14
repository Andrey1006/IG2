import SwiftUI

struct FixturesScreen: View {
    @EnvironmentObject private var club: Clubhouse
    @EnvironmentObject private var dugout: Dugout
    @State private var pitch: Int?
    @State private var shifting = false

    var body: some View {
        if let t = club.tournament {
            content(t)
        }
    }

    private func content(_ t: Tournament) -> some View {
        let shown = t.fixtures
            .filter { pitch == nil || $0.pitch == pitch }
            .sorted { $0.kickoff == $1.kickoff ? $0.pitch < $1.pitch : $0.kickoff < $1.kickoff }
        let blocks = Dictionary(grouping: shown) { BlockKey(stage: $0.stage) }
            .sorted { ($0.value.map(\.kickoff).min() ?? .now) < ($1.value.map(\.kickoff).min() ?? .now) }

        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    Masthead(kicker: "\(Clockface.day.string(from: t.start)) · \(t.played)/\(t.fixtures.count) played", title: t.name)
                    Button {
                        shifting = true
                    } label: {
                        Text("⏱")
                            .font(.system(size: 20))
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(Turf.pitch))
                    }
                    .buttonStyle(Squash())
                    .accessibilityLabel("Shift a pitch")
                }

                OnThePitch(t: t)

                if t.pitches > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filter(nil, "All pitches")
                            ForEach(0..<t.pitches, id: \.self) { p in
                                filter(p, "Pitch \(Stage.pitchName(p))")
                            }
                        }
                    }
                }

                if shown.isEmpty {
                    EmptyPitch(
                        art: .centreSpot,
                        title: "Nothing on this pitch",
                        message: "No fixtures were laid out here. Pick another pitch or view them all.",
                        action: ("Show all pitches", { pitch = nil })
                    )
                } else {
                    ForEach(blocks, id: \.key) { key, list in
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(text: key.title, trailing: "\(list.filter { $0.status == .finished }.count)/\(list.count)")
                            ForEach(list) { f in
                                Button {
                                    dugout.path(.fixtures).wrappedValue.append(.fixture(f.id))
                                } label: {
                                    FixtureTicket(t: t, f: f, showStage: key.mixed)
                                }
                                .buttonStyle(Squash())
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .turfScreen()
        .sheet(isPresented: $shifting) {
            ShiftSheet(t: t)
        }
    }

    private func filter(_ p: Int?, _ label: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { pitch = p }
            Buzz.tick()
        } label: {
            Chip(text: label, on: pitch == p)
        }
        .buttonStyle(Squash())
    }
}

private struct BlockKey: Hashable {
    let kind: Stage.Kind
    let round: Int

    init(stage: Stage) {
        kind = stage.kind == .bronze ? .knockout : stage.kind
        round = stage.kind == .bronze ? 1 : stage.round
    }

    var mixed: Bool { kind == .group }

    var title: String {
        switch kind {
        case .group: return "Group stage · Round \(round)"
        case .league: return "Matchday \(round)"
        default: return round == 1 ? "Finals day" : Stage(kind: .knockout, round: round).roundName
        }
    }
}

private struct OnThePitch: View {
    let t: Tournament
    @EnvironmentObject private var dugout: Dugout

    var body: some View {
        let cards = (0..<t.pitches).compactMap { p -> (Int, Fixture)? in
            let list = t.fixtures.filter { $0.pitch == p }.sorted { $0.kickoff < $1.kickoff }
            if let live = list.first(where: { $0.status == .live }) { return (p, live) }
            if let next = list.first(where: { $0.status == .scheduled }) { return (p, next) }
            return nil
        }

        if cards.isEmpty {
            champion
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(cards, id: \.0) { p, f in
                        Button {
                            if f.status == .live || t.isReady(f) {
                                dugout.whistle(f.id)
                            } else {
                                dugout.path(.fixtures).wrappedValue.append(.fixture(f.id))
                            }
                        } label: {
                            card(p, f)
                        }
                        .buttonStyle(Squash())
                    }
                }
            }
        }
    }

    private func card(_ p: Int, _ f: Fixture) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PITCH \(Stage.pitchName(p))")
                    .font(.copy(11, .heavy))
                    .tracking(1.4)
                    .foregroundColor(f.status == .live ? Turf.ink : Turf.floodlight)
                Spacer()
                if f.status == .live {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Text(Clockface.stopwatch(f.clock.elapsed(at: ctx.date)))
                            .font(.tally(12, .bold))
                            .foregroundColor(Turf.ink)
                    }
                } else {
                    Text("NEXT · \(Clockface.time.string(from: f.kickoff))")
                        .font(.tally(11, .bold))
                        .foregroundColor(Turf.haze)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(code(f.home))
                Text(f.status == .live ? "\(f.goals(.home))–\(f.goals(.away))" : "v")
                    .foregroundColor(f.status == .live ? Turf.ink : Turf.haze)
                Text(code(f.away))
            }
            .font(.scoreboard(30))
            .foregroundColor(f.status == .live ? Turf.ink : Turf.chalk)
            Text(f.status == .live ? "Tap to referee" : (t.isReady(f) ? "Tap to kick off" : "Waiting for results"))
                .font(.copy(12, .bold))
                .foregroundColor(f.status == .live ? Turf.inkHaze : Turf.haze)
        }
        .padding(16)
        .frame(width: 210, alignment: .leading)
        .flagCard(f.status == .live ? Turf.floodlight : Turf.pitch, radius: 18, notch: 22)
    }

    private func code(_ seat: Seat) -> String {
        t.team(at: seat)?.code ?? "TBD"
    }

    @ViewBuilder
    private var champion: some View {
        if let champ = t.podium.champion {
            HStack(spacing: 14) {
                Art(art: .trophy, height: 74)
                VStack(alignment: .leading, spacing: 3) {
                    Text("CHAMPIONS")
                        .font(.copy(11, .heavy))
                        .tracking(1.8)
                        .foregroundColor(Turf.inkGold)
                    Text(champ.name)
                        .font(.banner(24))
                        .foregroundColor(Turf.ink)
                    Text("Every fixture is done. Share the poster from Desk.")
                        .font(.copy(12))
                        .foregroundColor(Turf.inkHaze)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .flagCard(Turf.paper)
        }
    }
}
