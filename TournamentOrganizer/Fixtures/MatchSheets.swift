import SwiftUI

struct IncidentSheet: View {
    let t: Tournament
    let f: Fixture
    let onSave: (Incident) -> Void
    @EnvironmentObject private var club: Clubhouse
    @Environment(\.dismiss) private var dismiss
    @State private var kind = Incident.Kind.goal
    @State private var side = Side.home
    @State private var player: UUID?
    @State private var minute = 1
    @State private var newName = ""

    private var roster: [Player] {
        club.tournament?.team(at: f.seat(side))?.players ?? []
    }

    var body: some View {
        ZStack {
            Turf.night.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Masthead(kicker: f.stage.title, title: "Add to the log")
                        Button("Cancel") { dismiss() }
                            .buttonStyle(ChalkLineButton(compact: true))
                    }

                    HStack(spacing: 8) {
                        ForEach(Incident.Kind.allCases, id: \.self) { k in
                            Button {
                                kind = k
                                Buzz.tick()
                            } label: {
                                VStack(spacing: 4) {
                                    Text(k.emoji).font(.system(size: 22))
                                    Text(k.label)
                                        .font(.copy(11, .heavy))
                                        .foregroundColor(kind == k ? Turf.ink : Turf.haze)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 66)
                                .background(RoundedRectangle(cornerRadius: 14).fill(kind == k ? Turf.chalk : Turf.pitch))
                            }
                            .buttonStyle(Squash())
                        }
                    }

                    SectionLabel(text: kind == .ownGoal ? "Whose player put it in" : "Team")
                    HStack(spacing: 8) {
                        ForEach(Side.allCases, id: \.self) { s in
                            Button {
                                side = s
                                player = nil
                                Buzz.tick()
                            } label: {
                                HStack {
                                    Kit(index: t.team(at: f.seat(s))?.kit ?? 0)
                                    Text(t.label(f.seat(s)))
                                        .lineLimit(1)
                                }
                                .font(.copy(14, .bold))
                                .foregroundColor(side == s ? Turf.ink : Turf.chalk)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Capsule().fill(side == s ? Turf.floodlight : Turf.pitch))
                            }
                            .buttonStyle(Squash())
                        }
                    }

                    SectionLabel(text: "Player")
                    PlayerChips(players: roster, selected: $player)
                    HStack(spacing: 8) {
                        ChalkField(placeholder: "New player", text: $newName, size: 15)
                        Button("Add") {
                            guard let team = t.team(at: f.seat(side)),
                                  let p = club.addPlayer(newName, number: nil, to: team.id) else {
                                Buzz.deny()
                                return
                            }
                            player = p.id
                            newName = ""
                            Buzz.tick()
                        }
                        .buttonStyle(ChalkLineButton(compact: true))
                    }

                    Counter(title: "Minute", value: $minute, range: 1...max(t.matchMinutes * 2, 60), unit: "′")
                        .padding(.horizontal, 16)
                        .flagCard()

                    Button("Save") {
                        onSave(Incident(kind: kind, minute: minute, side: side, player: player))
                        dismiss()
                    }
                    .buttonStyle(FloodlitButton())
                }
                .padding(22)
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
        .onAppear {
            minute = min(f.clock.minute(at: .now), t.matchMinutes)
        }
    }
}

struct PlayerChips: View {
    let players: [Player]
    @Binding var selected: UUID?
    var barred: Set<UUID> = []

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
            ForEach(players) { p in
                Button {
                    guard !barred.contains(p.id) else {
                        Buzz.deny()
                        return
                    }
                    selected = selected == p.id ? nil : p.id
                    Buzz.tick()
                } label: {
                    HStack(spacing: 6) {
                        if let n = p.number {
                            Text("\(n)").font(.tally(12, .bold))
                        }
                        Text(p.shortName)
                            .font(.copy(13, .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .strikethrough(barred.contains(p.id))
                    }
                    .foregroundColor(selected == p.id ? Turf.ink : (barred.contains(p.id) ? Turf.haze.opacity(0.5) : Turf.chalk))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Capsule().fill(selected == p.id ? Turf.chalk : Turf.pitch))
                }
                .buttonStyle(Squash())
            }
        }
    }
}

struct MoveSheet: View {
    let t: Tournament
    let f: Fixture
    @EnvironmentObject private var club: Clubhouse
    @Environment(\.dismiss) private var dismiss
    @State private var pitch = 0
    @State private var offset = 0

    var body: some View {
        ZStack {
            Turf.night.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Masthead(kicker: f.stage.title, title: "Move fixture")
                    Button("Cancel") { dismiss() }
                        .buttonStyle(ChalkLineButton(compact: true))
                }
                if t.pitches > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<t.pitches, id: \.self) { p in
                            Button {
                                pitch = p
                                Buzz.tick()
                            } label: { Chip(text: "Pitch \(Stage.pitchName(p))", on: pitch == p) }
                            .buttonStyle(Squash())
                        }
                    }
                }
                VStack(spacing: 6) {
                    Text(Clockface.time.string(from: f.kickoff.addingTimeInterval(TimeInterval(offset * 60))))
                        .font(.scoreboard(56))
                        .foregroundColor(Turf.chalk)
                    Counter(title: "Shift", value: $offset, range: -180...180, step: 5, unit: "′")
                }
                .padding(18)
                .flagCard()

                let clash = t.fixtures.first {
                    $0.id != f.id && $0.pitch == pitch
                        && abs($0.kickoff.timeIntervalSince(f.kickoff.addingTimeInterval(TimeInterval(offset * 60)))) < TimeInterval(t.matchMinutes * 60)
                }
                if let clash {
                    Text("⚠️ Overlaps \(clash.stage.title) on Pitch \(Stage.pitchName(pitch)) at \(Clockface.time.string(from: clash.kickoff)).")
                        .font(.copy(13, .semibold))
                        .foregroundColor(Turf.booking)
                }
                Spacer()
                Button("Save") {
                    club.editFixture(f.id) {
                        $0.pitch = pitch
                        $0.kickoff.addTimeInterval(TimeInterval(offset * 60))
                    }
                    Buzz.success()
                    dismiss()
                }
                .buttonStyle(FloodlitButton())
            }
            .padding(22)
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
        .onAppear { pitch = f.pitch }
    }
}

struct ShootoutSheet: View {
    let t: Tournament
    let f: Fixture
    let onSave: (Shootout) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var home = 0
    @State private var away = 0

    var body: some View {
        ZStack {
            Turf.night.ignoresSafeArea()
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button("Not yet") { dismiss() }
                        .buttonStyle(ChalkLineButton(compact: true))
                }
                Text("🎯 Penalty shootout")
                    .font(.banner(26))
                    .foregroundColor(Turf.chalk)
                Text("Level at \(f.goals(.home))–\(f.goals(.away)). Shootout goals don't count for the scorers.")
                    .font(.copy(14))
                    .foregroundColor(Turf.haze)
                    .multilineTextAlignment(.center)
                HStack(spacing: 18) {
                    spot(.home, $home)
                    Text(":").font(.scoreboard(44)).foregroundColor(Turf.haze)
                    spot(.away, $away)
                }
                if home == away {
                    Text("Someone has to miss.")
                        .font(.copy(13, .bold))
                        .foregroundColor(Turf.booking)
                }
                Spacer()
                Button("Confirm winner") {
                    guard home != away else {
                        Buzz.deny()
                        return
                    }
                    onSave(Shootout(home: home, away: away))
                    Buzz.success()
                    dismiss()
                }
                .buttonStyle(FloodlitButton(fill: home == away ? Turf.stripe : Turf.floodlight, text: home == away ? Turf.haze : Turf.ink))
            }
            .padding(24)
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
        .onAppear {
            home = f.shootout?.home ?? 0
            away = f.shootout?.away ?? 0
        }
    }

    private func spot(_ side: Side, _ value: Binding<Int>) -> some View {
        VStack(spacing: 10) {
            Text(t.team(at: f.seat(side))?.code ?? "?")
                .font(.copy(14, .heavy))
                .foregroundColor(Turf.haze)
            Text("\(value.wrappedValue)")
                .font(.scoreboard(64))
                .foregroundColor(Turf.chalk)
                .contentTransition(.numericText())
            HStack(spacing: 10) {
                Button {
                    if value.wrappedValue > 0 { value.wrappedValue -= 1 }
                    Buzz.tick()
                } label: { Image(systemName: "minus") }
                Button {
                    value.wrappedValue += 1
                    Buzz.threshold()
                } label: { Image(systemName: "plus") }
            }
            .font(.system(size: 15, weight: .heavy))
            .foregroundColor(Turf.ink)
            .buttonStyle(Squash())
            .labelStyle(.iconOnly)
            .frame(height: 36)
            .padding(.horizontal, 12)
            .background(Capsule().fill(Turf.chalk))
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.25), value: value.wrappedValue)
    }
}
