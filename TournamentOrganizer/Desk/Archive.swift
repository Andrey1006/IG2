import SwiftUI

struct RulesScreen: View {
    @EnvironmentObject private var club: Clubhouse

    var body: some View {
        if let t = club.tournament {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    BackBar(title: "Desk")
                        .padding(.horizontal, -18)
                    Masthead(kicker: t.name, title: "House rules")
                    RulesCard(
                        rules: Binding(get: { club.tournament?.rules ?? t.rules }, set: { r in club.edit { $0.rules = r } }),
                        format: t.format,
                        lockBronze: true
                    )
                    if t.played > 0 {
                        Text("⚠️ \(t.played) matches are already played. Tables, bans and the bracket recalculate with the new rules straight away.")
                            .font(.copy(13, .semibold))
                            .foregroundColor(Turf.booking)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }
            .turfScreen()
        }
    }
}

struct HallScreen: View {
    @EnvironmentObject private var club: Clubhouse

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                BackBar(title: "Desk")
                    .padding(.horizontal, -18)
                Masthead(kicker: "Every cup you've run", title: "Hall of Fame")

                if club.book.honours.isEmpty {
                    EmptyPitch(
                        art: .trophyShelf,
                        title: "The shelf is empty",
                        message: "Close a tournament from Desk and its champion, runner-up and top scorer land here."
                    )
                } else {
                    ForEach(club.book.honours) { h in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(h.name)
                                    .font(.banner(20))
                                    .foregroundColor(Turf.ink)
                                Spacer()
                                Text(Clockface.day.string(from: h.date))
                                    .font(.tally(12, .bold))
                                    .foregroundColor(Turf.inkHaze)
                            }
                            HStack(spacing: 10) {
                                Text("🏆").font(.system(size: 30))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(h.champion ?? "Unfinished")
                                        .font(.banner(18))
                                        .foregroundColor(h.champion == nil ? Turf.inkHaze : Turf.inkGold)
                                    if let r = h.runnerUp {
                                        Text("Runner-up · \(r)")
                                            .font(.copy(13, .semibold))
                                            .foregroundColor(Turf.inkHaze)
                                    }
                                }
                            }
                            if let s = h.topScorer {
                                Text("👟 \(s) — \(h.topGoals) goals")
                                    .font(.copy(14, .bold))
                                    .foregroundColor(Turf.ink)
                            }
                            Text("\(h.teams) teams · \(h.fixtures) matches · \(h.goals) goals")
                                .font(.tally(12))
                                .foregroundColor(Turf.inkHaze)
                        }
                        .padding(18)
                        .flagCard(Turf.paper)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 40)
        }
        .turfScreen()
    }
}
