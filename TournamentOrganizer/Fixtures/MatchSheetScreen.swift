import SwiftUI

struct MatchSheetScreen: View {
    let fixtureID: UUID
    @EnvironmentObject private var club: Clubhouse
    @EnvironmentObject private var dugout: Dugout
    @State private var adding = false
    @State private var moving = false
    @State private var shootout = false
    @State private var starring = false
    @State private var held: Tournament?
    @State private var heldNotes: [String] = []

    var body: some View {
        if let t = club.tournament, let f = t.fixture(fixtureID) {
            content(t, f)
        } else {
            VStack {
                BackBar(title: "Match")
                EmptyPitch(art: .centreSpot, title: "Match not found", message: "This fixture no longer exists.")
                Spacer()
            }
            .turfScreen()
        }
    }

    private func content(_ t: Tournament, _ f: Fixture) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                BackBar(title: f.stage.title)
                    .padding(.horizontal, -18)

                Scoreline(t: t, f: f)

                actions(t, f)

                if f.status == .finished {
                    starCard(t, f)
                }

                let out = Side.allCases.flatMap { side in
                    t.unavailable(in: f, side: side).compactMap { t.roster(of: $0)?.0.name }
                }
                if !out.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Text("🚫")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Suspended for this match")
                                .font(.copy(13, .heavy))
                                .foregroundColor(Turf.dismissal)
                            Text(out.joined(separator: ", "))
                                .font(.copy(14, .semibold))
                                .foregroundColor(Turf.chalk)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Turf.dismissal.opacity(0.14)))
                }

                SectionLabel(text: "Match log", trailing: "\(f.incidents.count)")

                if f.incidents.isEmpty {
                    Text(f.status == .scheduled ? "Kick off to start the log." : "Nothing happened yet. A goalless draw in the making?")
                        .font(.copy(14))
                        .foregroundColor(Turf.haze)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 6) {
                        ForEach(f.incidents) { i in
                            IncidentLine(t: t, f: f, incident: i) {
                                commit { $0.fixtures[index(t)].incidents.removeAll { $0.id == i.id } }
                            }
                        }
                    }
                }

                if f.status != .scheduled {
                    Button {
                        adding = true
                    } label: {
                        Label("Add goal or card", systemImage: "plus").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ChalkLineButton(tint: Turf.floodlight))
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 40)
        }
        .turfScreen()
        .sheet(isPresented: $adding) {
            IncidentSheet(t: t, f: f) { incident in
                commit { $0.fixtures[index(t)].incidents.append(incident) }
            }
        }
        .sheet(isPresented: $moving) { MoveSheet(t: t, f: f) }
        .sheet(isPresented: $starring) {
            StarSheet(t: t, f: f) { club.crown($0, in: f.id) }
        }
        .sheet(isPresented: $shootout) {
            ShootoutSheet(t: t, f: f) { s in
                commit { $0.fixtures[index(t)].shootout = s }
            }
        }
        .alert("This rewrites the bracket", isPresented: Binding(get: { held != nil }, set: { if !$0 { held = nil } })) {
            Button("Save anyway", role: .destructive) {
                if let held { club.replace(held) }
                held = nil
            }
            Button("Cancel", role: .cancel) { held = nil }
        } message: {
            Text("Played matches keep their line-ups:\n" + heldNotes.joined(separator: "\n"))
        }
    }

    private func starCard(_ t: Tournament, _ f: Fixture) -> some View {
        let star = f.star.flatMap { t.roster(of: $0) }
        return Button {
            starring = true
        } label: {
            HStack(spacing: 14) {
                Text("⭐️")
                    .font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text("PLAYER OF THE MATCH")
                        .font(.copy(11, .heavy))
                        .tracking(1.4)
                        .foregroundColor(Turf.floodlight)
                    Text(star?.0.name ?? "Tap to pick")
                        .font(.copy(17, .bold))
                        .foregroundColor(star == nil ? Turf.haze : Turf.chalk)
                }
                Spacer()
                if let team = star?.1 {
                    Kit(index: team.kit, size: 24, crest: team.crest)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Turf.haze)
            }
            .padding(16)
            .flagCard(radius: 18, notch: 18)
        }
        .buttonStyle(Squash())
    }

    private func index(_ t: Tournament) -> Int {
        t.fixtures.firstIndex { $0.id == fixtureID } ?? 0
    }

    private func commit(_ change: (inout Tournament) -> Void) {
        guard let t = club.tournament else { return }
        var next = t
        change(&next)
        let i = index(next)
        next.fixtures[i].incidents.sort { $0.minute < $1.minute }
        if next.fixtures[i].stage.isKnockout && !next.fixtures[i].isTied {
            next.fixtures[i].shootout = nil
        }
        let notes = t.displaced(after: next)
        if notes.isEmpty || t.fixtures[i].status == .live {
            club.replace(next)
            Buzz.tick()
        } else {
            heldNotes = notes
            held = next
            Buzz.threshold()
        }
    }

    @ViewBuilder
    private func actions(_ t: Tournament, _ f: Fixture) -> some View {
        HStack(spacing: 10) {
            switch f.status {
            case .scheduled:
                Button(t.isReady(f) ? "Kick off ⚽️" : "Teams not known yet") {
                    guard t.isReady(f) else {
                        Buzz.deny()
                        return
                    }
                    club.kickOff(f.id)
                    Buzz.thud()
                    dugout.paths[.fixtures] = []
                    dugout.whistle(f.id)
                }
                .buttonStyle(FloodlitButton(fill: t.isReady(f) ? Turf.floodlight : Turf.stripe, text: t.isReady(f) ? Turf.ink : Turf.haze))
            case .live:
                Button("Open on the Whistle") {
                    dugout.paths[.fixtures] = []
                    dugout.whistle(f.id)
                }
                .buttonStyle(FloodlitButton())
            case .finished:
                if f.stage.isKnockout && f.isTied {
                    Button(f.shootout == nil ? "Enter shootout 🎯" : "Edit shootout") { shootout = true }
                        .buttonStyle(FloodlitButton(fill: f.shootout == nil ? Turf.booking : Turf.chalk))
                }
            }
            if f.status == .scheduled {
                Button {
                    moving = true
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
                .buttonStyle(ChalkLineButton())
                .frame(width: 70)
            }
        }
    }
}

struct Scoreline: View {
    let t: Tournament
    let f: Fixture

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("PITCH \(Stage.pitchName(f.pitch)) · \(Clockface.time.string(from: f.kickoff))")
                    .font(.tally(12, .bold))
                    .foregroundColor(Turf.haze)
                Spacer()
                StatusMark(f: f)
            }
            HStack(alignment: .center, spacing: 8) {
                club(.home)
                VStack(spacing: 2) {
                    Text(f.status == .scheduled ? "v" : "\(f.goals(.home)) : \(f.goals(.away))")
                        .font(.scoreboard(f.status == .scheduled ? 34 : 54))
                        .foregroundColor(Turf.chalk)
                    if let s = f.shootout {
                        Text("pens \(s.home)–\(s.away)")
                            .font(.tally(12, .bold))
                            .foregroundColor(Turf.floodlight)
                    }
                }
                .frame(minWidth: 110)
                club(.away)
            }
        }
        .padding(18)
        .flagCard()
    }

    private func club(_ side: Side) -> some View {
        let team = t.team(at: f.seat(side))
        return VStack(spacing: 8) {
            Kit(index: team?.kit ?? 10, size: 38, crest: team?.crest)
            Text(t.label(f.seat(side)))
                .font(.banner(16))
                .foregroundColor(team == nil ? Turf.haze : Turf.chalk)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

struct IncidentLine: View {
    let t: Tournament
    let f: Fixture
    let incident: Incident
    let onStrike: () -> Void

    var body: some View {
        let name = incident.player.flatMap { t.roster(of: $0)?.0.name } ?? "Unknown player"
        let team = t.team(at: f.seat(incident.side))
        let helper = incident.assist.flatMap { t.roster(of: $0)?.0.shortName }
        HStack(spacing: 10) {
            Text("\(incident.minute)′")
                .font(.tally(13, .bold))
                .foregroundColor(Turf.haze)
                .frame(width: 34, alignment: .leading)
            Text(incident.kind.emoji)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.copy(15, .bold))
                    .foregroundColor(Turf.chalk)
                Text([incident.kind.label, helper.map { "assist \($0)" }, team?.name].compactMap { $0 }.joined(separator: " · "))
                    .font(.copy(12))
                    .lineLimit(1)
                    .foregroundColor(Turf.haze)
            }
            Spacer()
            Button(action: onStrike) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(Turf.haze)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Turf.night.opacity(0.6)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Turf.pitch)
                .overlay(alignment: incident.side == .home ? .leading : .trailing) {
                    Rectangle().fill(Turf.kit(team?.kit ?? 10)).frame(width: 3).padding(.vertical, 10)
                }
        )
    }
}
