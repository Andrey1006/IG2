import SwiftUI

struct TableScreen: View {
    @EnvironmentObject private var club: Clubhouse
    @State private var view = 0

    var body: some View {
        if let t = club.tournament {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Masthead(kicker: t.format.title, title: t.format == .knockout ? "The Bracket" : "Standings")

                    if t.format == .groups {
                        ChalkTabs(options: [(0, "Groups"), (1, "Bracket")], selection: $view)
                    }

                    if t.format == .knockout || (t.format == .groups && view == 1) {
                        BracketBoard(t: t)
                            .padding(.horizontal, -18)
                    } else if t.format == .league {
                        StandingsCard(t: t, group: nil, title: "League table", zone: 1)
                    } else {
                        ForEach(0..<t.groups.count, id: \.self) { g in
                            StandingsCard(t: t, group: g, title: "Group \(Stage.letter(g))", zone: t.advance)
                        }
                    }

                    if t.format != .knockout && !(t.format == .groups && view == 1) {
                        Text("Ties: points → head-to-head → goal difference → goals → fair play (🟨 1, 🟥 3) → draw order.")
                            .font(.copy(12))
                            .foregroundColor(Turf.haze)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
            .turfScreen()
        }
    }
}

struct StandingsCard: View {
    let t: Tournament
    let group: Int?
    let title: String
    let zone: Int
    @EnvironmentObject private var dugout: Dugout

    var body: some View {
        let rows = t.table(group: group)
        let live = Set(t.fixtures.filter { $0.status == .live }.flatMap { [t.resolve($0.home), t.resolve($0.away)] }.compactMap { $0 })
        let done = t.isComplete(group: group)

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title.uppercased())
                    .font(.copy(13, .heavy))
                    .tracking(1.6)
                    .foregroundColor(Turf.floodlight)
                Spacer()
                Text(done ? "FINAL" : "\(t.groupFixtures(group).filter { $0.status == .finished }.count)/\(t.groupFixtures(group).count)")
                    .font(.tally(11, .bold))
                    .foregroundColor(done ? Turf.floodlight : Turf.haze)
            }
            .padding(.bottom, 10)

            HStack(spacing: 0) {
                Text("#").frame(width: 22, alignment: .leading)
                Text("TEAM").frame(maxWidth: .infinity, alignment: .leading)
                ForEach(["P", "W", "D", "L", "GD"], id: \.self) { Text($0).frame(width: 26) }
                Text("PTS").frame(width: 36, alignment: .trailing)
            }
            .font(.copy(10, .heavy))
            .foregroundColor(Turf.haze)
            .padding(.bottom, 6)

            ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                Button {
                    dugout.path(.table).wrappedValue.append(.team(row.team.id))
                } label: {
                    HStack(spacing: 0) {
                        Text("\(i + 1)")
                            .font(.tally(13, .bold))
                            .foregroundColor(i < zone ? Turf.floodlight : Turf.haze)
                            .frame(width: 22, alignment: .leading)
                        HStack(spacing: 7) {
                            Kit(index: row.team.kit, size: 12)
                            Text(row.team.name)
                                .font(.copy(14, .bold))
                                .foregroundColor(Turf.chalk)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            if live.contains(row.team.id) { LiveDot() }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Group {
                            Text("\(row.played)").frame(width: 26)
                            Text("\(row.won)").frame(width: 26)
                            Text("\(row.drawn)").frame(width: 26)
                            Text("\(row.lost)").frame(width: 26)
                            Text(row.diff > 0 ? "+\(row.diff)" : "\(row.diff)").frame(width: 26)
                        }
                        .font(.tally(12))
                        .foregroundColor(Turf.chalk.opacity(0.85))
                        Text("\(row.points)")
                            .font(.scoreboard(20))
                            .foregroundColor(Turf.chalk)
                            .frame(width: 36, alignment: .trailing)
                    }
                    .padding(.vertical, 9)
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(i < zone ? Turf.floodlight.opacity(0.08) : .clear)
                    )
                    .overlay(alignment: .leading) {
                        if i < zone {
                            Capsule().fill(Turf.floodlight).frame(width: 3).padding(.vertical, 8).offset(x: -6)
                        }
                    }
                }
                .buttonStyle(Squash())
                if i == zone - 1 && i < rows.count - 1 {
                    Rectangle()
                        .fill(Turf.chalk.opacity(0.25))
                        .frame(height: 1)
                        .overlay(Rectangle().stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundColor(Turf.night))
                        .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .flagCard()
    }
}
