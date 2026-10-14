import SwiftUI

struct TeamScreen: View {
    let teamID: UUID
    @EnvironmentObject private var club: Clubhouse
    @EnvironmentObject private var dugout: Dugout
    @State private var editing = false

    var body: some View {
        if let t = club.tournament, let team = t.team(teamID) {
            content(t, team)
        }
    }

    private func content(_ t: Tournament, _ team: Team) -> some View {
        let games = t.fixtures(of: team.id)
        let scorers = Dictionary(uniqueKeysWithValues: t.scorers.filter { $0.team.id == team.id }.map { ($0.player.id, $0.goals) })
        let banned = Set(t.suspensions.filter { $0.team.id == team.id }.map(\.id))
        let tab = dugout.tab

        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                BackBar(title: "Team")
                    .padding(.horizontal, -18)

                HStack(spacing: 16) {
                    ZStack {
                        Pennant()
                            .fill(Turf.kit(team.kit))
                            .frame(width: 64, height: 80)
                        Text(team.code)
                            .font(.banner(18))
                            .foregroundColor(team.kit == 3 || team.kit == 2 ? Turf.ink : Turf.chalk)
                            .offset(y: -6)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(team.name)
                            .font(.banner(28))
                            .foregroundColor(Turf.chalk)
                        Text(groupLine(t, team))
                            .font(.copy(14, .semibold))
                            .foregroundColor(Turf.haze)
                    }
                }

                HStack {
                    SectionLabel(text: "Squad", trailing: "\(team.players.count)")
                    Button("Edit") { editing = true }
                        .buttonStyle(ChalkLineButton(compact: true))
                }

                if team.players.isEmpty {
                    Text("No players listed. Add them now or straight from the Whistle when someone scores.")
                        .font(.copy(14))
                        .foregroundColor(Turf.haze)
                } else {
                    VStack(spacing: 6) {
                        ForEach(team.players) { p in
                            Button {
                                dugout.path(tab).wrappedValue.append(.player(p.id))
                            } label: {
                                HStack(spacing: 10) {
                                    Text(p.number.map { "\($0)" } ?? "–")
                                        .font(.scoreboard(18))
                                        .foregroundColor(Turf.floodlight)
                                        .frame(width: 30)
                                    Text(p.name)
                                        .font(.copy(15, .bold))
                                        .foregroundColor(Turf.chalk)
                                    if banned.contains(p.id) { Text("🚫") }
                                    Spacer()
                                    if let g = scorers[p.id] {
                                        Text("⚽️ \(g)")
                                            .font(.tally(13, .bold))
                                            .foregroundColor(Turf.chalk)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .frame(height: 46)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Turf.pitch))
                            }
                            .buttonStyle(Squash())
                        }
                    }
                }

                SectionLabel(text: "Fixtures", trailing: "\(games.count)")
                ForEach(games) { f in
                    Button {
                        dugout.path(tab).wrappedValue.append(.fixture(f.id))
                    } label: {
                        FixtureTicket(t: t, f: f, showStage: true)
                    }
                    .buttonStyle(Squash())
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 40)
        }
        .turfScreen()
        .sheet(isPresented: $editing) {
            RosterSheet(team: Binding(
                get: { club.tournament?.team(teamID) ?? team },
                set: { updated in
                    club.edit { t in
                        guard let i = t.teams.firstIndex(where: { $0.id == teamID }) else { return }
                        t.teams[i].players = updated.players
                    }
                }
            ))
        }
    }

    private func groupLine(_ t: Tournament, _ team: Team) -> String {
        if let g = t.groups.firstIndex(where: { $0.contains(team.id) }) {
            let rank = (t.table(group: g).firstIndex { $0.team.id == team.id } ?? 0) + 1
            return "Group \(Stage.letter(g)) · \(rank.ordinal) place"
        }
        if t.format == .league {
            let rank = (t.table(group: nil).firstIndex { $0.team.id == team.id } ?? 0) + 1
            return "\(rank.ordinal) in the league"
        }
        return team.seeded ? "Seeded ⭐️" : "Unseeded"
    }
}
