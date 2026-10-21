import SwiftUI

struct PlayerScreen: View {
    let playerID: UUID
    @EnvironmentObject private var club: Clubhouse
    @EnvironmentObject private var dugout: Dugout

    var body: some View {
        if let t = club.tournament, let (p, team) = t.roster(of: playerID) {
            let log = t.log(of: p.id)
            let all = log.flatMap(\.1)
            let ban = t.suspensions.first { $0.id == p.id }
            let tab = dugout.tab

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    BackBar(title: team.name)
                        .padding(.horizontal, -18)

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.number.map { "#\($0)" } ?? "Squad player")
                                .font(.copy(12, .heavy))
                                .tracking(1.4)
                                .foregroundColor(Turf.floodlight)
                            Text(p.name)
                                .font(.banner(30))
                                .foregroundColor(Turf.chalk)
                        }
                        Spacer()
                        Kit(index: team.kit, size: 36, crest: team.crest)
                    }

                    let own = all.filter { $0.player == p.id }
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            tile("⚽️", own.filter { $0.kind == .goal }.count, "goals")
                            tile("🅰️", all.filter { $0.assist == p.id }.count, "assists")
                            tile("⭐️", t.fixtures.filter { $0.star == p.id }.count, "MOTM")
                        }
                        HStack(spacing: 10) {
                            tile("🟨", own.filter { $0.kind == .yellow }.count, "yellows")
                            tile("🟥", own.filter { $0.kind == .red }.count, "reds")
                        }
                    }

                    if let ban {
                        Text("🚫 Suspended for the next \(ban.matches == 1 ? "match" : "\(ban.matches) matches")")
                            .font(.copy(14, .heavy))
                            .foregroundColor(Turf.dismissal)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Turf.dismissal.opacity(0.14)))
                    }

                    SectionLabel(text: "Match by match")
                    if log.isEmpty {
                        Text("Nothing on the scoresheet yet.")
                            .font(.copy(14))
                            .foregroundColor(Turf.haze)
                    }
                    ForEach(log, id: \.0.id) { f, incidents in
                        Button {
                            dugout.path(tab).wrappedValue.append(.fixture(f.id))
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.stage.title)
                                        .font(.copy(11, .heavy))
                                        .foregroundColor(Turf.haze)
                                    Text("\(t.team(at: f.home)?.code ?? "") \(f.goals(.home))–\(f.goals(.away)) \(t.team(at: f.away)?.code ?? "")")
                                        .font(.copy(15, .bold))
                                        .foregroundColor(Turf.chalk)
                                }
                                Spacer()
                                Text(((f.star == p.id ? ["⭐️"] : []) + incidents.map { "\($0.player == p.id ? $0.kind.emoji : "🅰️")\($0.minute)′" }).joined(separator: " "))
                                    .font(.tally(12))
                                    .foregroundColor(Turf.chalk)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Turf.pitch))
                        }
                        .buttonStyle(Squash())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }
            .turfScreen()
        }
    }

    private func tile(_ emoji: String, _ n: Int, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.system(size: 20))
            Text("\(n)")
                .font(.scoreboard(34))
                .foregroundColor(Turf.chalk)
            Text(label.uppercased())
                .font(.copy(10, .heavy))
                .foregroundColor(Turf.haze)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .flagCard(radius: 16, notch: 16)
    }
}
