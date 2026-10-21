import SwiftUI

struct LeadersScreen: View {
    @EnvironmentObject private var club: Clubhouse
    @EnvironmentObject private var dugout: Dugout
    @State private var tab = 0

    var body: some View {
        if let t = club.tournament {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Masthead(kicker: "\(t.totalGoals) goals · \(t.played) matches", title: "Leaders")
                    ChalkTabs(options: [(0, "⚽️ Scorers"), (1, "🅰️ Assists"), (2, "🟨 Cards")], selection: $tab)
                    switch tab {
                    case 0: scorers(t)
                    case 1: assists(t)
                    default: discipline(t)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
            .turfScreen()
        }
    }

    @ViewBuilder
    private func scorers(_ t: Tournament) -> some View {
        let list = t.scorers
        if list.isEmpty {
            EmptyPitch(
                art: .goldenBoot,
                title: "No goals yet",
                message: "Swipe up on a team's half in the Whistle to put the first one on the board."
            )
        } else {
            Podium(t: t, top: Array(list.prefix(3)))
            board(list) { $0.goals }
        }
    }

    @ViewBuilder
    private func assists(_ t: Tournament) -> some View {
        let list = t.playmakers
        if list.isEmpty {
            EmptyPitch(
                art: .goldenBoot,
                title: "No assists yet",
                message: "After picking a scorer in the Whistle, tap who set it up."
            )
        } else {
            board(list) { $0.assists }
        }
    }

    private func board(_ list: [Scorer], value: @escaping (Scorer) -> Int) -> some View {
        let best = list.first.map(value) ?? 1
        return VStack(spacing: 6) {
            ForEach(Array(list.enumerated()), id: \.element.id) { i, s in
                Button {
                    dugout.path(.leaders).wrappedValue.append(.player(s.player.id))
                } label: {
                    HStack(spacing: 10) {
                        Text("\(rank(list, i, value))")
                            .font(.tally(13, .bold))
                            .foregroundColor(Turf.haze)
                            .frame(width: 24, alignment: .leading)
                        Kit(index: s.team.kit, size: 12, crest: s.team.crest)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.player.name)
                                .font(.copy(15, .bold))
                                .foregroundColor(Turf.chalk)
                            Text("\(s.team.name) · \(s.matches) played").lineLimit(1)
                                .font(.copy(11))
                                .foregroundColor(Turf.haze)
                        }
                        Spacer(minLength: 8)
                        GeometryReader { geo in
                            Capsule()
                                .fill(Turf.floodlight.opacity(0.85))
                                .frame(width: max(6, geo.size.width * CGFloat(value(s)) / CGFloat(max(best, 1))), height: 6)
                                .frame(maxHeight: .infinity)
                        }
                        .frame(width: 70)
                        Text("\(value(s))")
                            .font(.scoreboard(22))
                            .foregroundColor(Turf.chalk)
                            .frame(width: 30, alignment: .trailing)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 56)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Turf.pitch))
                }
                .buttonStyle(Squash())
            }
        }
    }

    private func rank(_ list: [Scorer], _ i: Int, _ value: (Scorer) -> Int) -> Int {
        (list.firstIndex { value($0) == value(list[i]) } ?? i) + 1
    }

    @ViewBuilder
    private func discipline(_ t: Tournament) -> some View {
        let bans = t.suspensions
        let brink = t.onTheBrink
        let cards = t.cardTable

        if bans.isEmpty && brink.isEmpty && cards.isEmpty {
            EmptyPitch(
                art: .cleanCards,
                title: "Spotless so far",
                message: "No bookings yet. Drag a card from the pocket onto a player in the Whistle when it happens."
            )
        } else {
            if !bans.isEmpty {
                SectionLabel(text: "Suspended", trailing: "\(bans.count)")
                ForEach(bans) { s in
                    Button {
                        dugout.path(.leaders).wrappedValue.append(.player(s.player.id))
                    } label: {
                        HStack(spacing: 12) {
                            CardFace(kind: s.reason == .red ? .red : .yellow)
                                .frame(width: 22, height: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.player.name)
                                    .font(.copy(15, .heavy))
                                    .foregroundColor(Turf.chalk)
                                Text("\(s.team.name) · \(s.reason == .red ? "sent off" : "\(t.rules.yellowLimit) yellows")")
                                    .font(.copy(12))
                                    .foregroundColor(Turf.haze)
                            }
                            Spacer()
                            VStack(spacing: 0) {
                                Text("\(s.matches)")
                                    .font(.scoreboard(24))
                                    .foregroundColor(Turf.dismissal)
                                Text(s.matches == 1 ? "MATCH" : "MATCHES")
                                    .font(.copy(9, .heavy))
                                    .foregroundColor(Turf.haze)
                            }
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Turf.dismissal.opacity(0.13)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Turf.dismissal.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(Squash())
                }
            }

            if !brink.isEmpty {
                SectionLabel(text: "One more and out", trailing: "\(brink.count)")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(brink, id: \.0.id) { p, team, n in
                        HStack(spacing: 8) {
                            Text(String(repeating: "🟨", count: min(n, 3))).font(.system(size: 11))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(p.shortName)
                                    .font(.copy(13, .bold))
                                    .foregroundColor(Turf.chalk)
                                    .lineLimit(1)
                                Text(team.code)
                                    .font(.copy(10, .heavy))
                                    .foregroundColor(Turf.haze)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Turf.booking.opacity(0.12)))
                    }
                }
            }

            if !cards.isEmpty {
                SectionLabel(text: "Fair play", trailing: "fewest first")
                VStack(spacing: 6) {
                    ForEach(cards) { line in
                        HStack(spacing: 10) {
                            Kit(index: line.team.kit, size: 12, crest: line.team.crest)
                            Text(line.team.name)
                                .font(.copy(14, .bold))
                                .foregroundColor(Turf.chalk)
                            Spacer()
                            Text("🟨 \(line.yellows)").font(.tally(12))
                            Text("🟥 \(line.reds)").font(.tally(12))
                            Text("\(line.points)")
                                .font(.scoreboard(18))
                                .frame(width: 30, alignment: .trailing)
                        }
                        .foregroundColor(Turf.chalk)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Turf.pitch))
                    }
                }
            }
        }
    }
}

private struct Podium: View {
    let t: Tournament
    let top: [Scorer]

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach([1, 0, 2], id: \.self) { i in
                if i < top.count {
                    step(top[i], place: i)
                } else {
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 6)
    }

    private func step(_ s: Scorer, place: Int) -> some View {
        let heights: [CGFloat] = [118, 88, 70]
        return VStack(spacing: 6) {
            if place == 0 {
                Art(art: .goldenBoot, height: 64)
            } else {
                Text(place == 1 ? "🥈" : "🥉").font(.system(size: 28))
            }
            Text(s.player.shortName)
                .font(.copy(13, .heavy))
                .foregroundColor(Turf.chalk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(s.team.code)
                .font(.copy(10, .heavy))
                .foregroundColor(Turf.haze)
            ZStack(alignment: .top) {
                CornerFlag(radius: 14, notch: place == 0 ? 18 : 12)
                    .fill(place == 0 ? Turf.floodlight : Turf.pitch)
                Text("\(s.goals)")
                    .font(.scoreboard(place == 0 ? 44 : 32))
                    .foregroundColor(place == 0 ? Turf.ink : Turf.chalk)
                    .padding(.top, 8)
            }
            .frame(height: heights[place])
        }
        .frame(maxWidth: .infinity)
    }
}
