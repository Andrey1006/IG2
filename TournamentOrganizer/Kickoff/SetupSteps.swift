import SwiftUI

struct EventStep: View {
    @ObservedObject var draft: Draft

    private var days: [(Date, String)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var out: [(Date, String)] = [(today, "Today")]
        if let t = cal.date(byAdding: .day, value: 1, to: today) { out.append((t, "Tomorrow")) }
        for weekday in [7, 1] {
            if let d = cal.nextDate(after: today, matching: DateComponents(weekday: weekday), matchingPolicy: .nextTime),
               !out.contains(where: { cal.isDate($0.0, inSameDayAs: d) }) {
                out.append((d, Clockface.day.string(from: d)))
            }
        }
        return out
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                ArtBand(art: .floodlights, height: 170)
                    .clipShape(CornerFlag(radius: 24, notch: 34))

                Masthead(kicker: "Match Bracket", title: "Set up the matchday")

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Tournament name")
                    ChalkField(placeholder: "Friday Office Cup", text: $draft.name, size: 19)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Kick-off")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(days, id: \.0) { d, label in
                                Button {
                                    draft.day = d
                                    Buzz.tick()
                                } label: {
                                    Chip(text: label, on: Calendar.current.isDate(draft.day, inSameDayAs: d))
                                }
                                .buttonStyle(Squash())
                            }
                        }
                    }
                    KickoffDial(minutes: $draft.clockMinutes)
                }
                .padding(18)
                .flagCard()

                VStack(spacing: 4) {
                    Counter(title: "Pitches", value: $draft.pitches, range: 1...4)
                    Divider().overlay(Turf.line)
                    Counter(title: "Match length", value: $draft.matchMinutes, range: 5...45, unit: "′")
                    Divider().overlay(Turf.line)
                    Counter(title: "Break between", value: $draft.breakMinutes, range: 0...20, unit: "′")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .flagCard()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

private struct KickoffDial: View {
    @Binding var minutes: Int
    @State private var anchor: Int?

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%02d:%02d", minutes / 60, minutes % 60))
                    .font(.scoreboard(54))
                    .foregroundColor(Turf.chalk)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.25), value: minutes)
                Text("drag sideways · 5 min steps")
                    .font(.copy(12))
                    .foregroundColor(Turf.haze)
            }
            Spacer()
            ruler
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { g in
                    let base = anchor ?? minutes
                    if anchor == nil { anchor = minutes }
                    let next = min(max(base + Int(g.translation.width / 9) * 5, 6 * 60), 23 * 60 + 30)
                    if next != minutes {
                        minutes = next
                        if next % 60 == 0 { Buzz.threshold() } else { Buzz.tick() }
                    }
                }
                .onEnded { _ in anchor = nil }
        )
    }

    private var ruler: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(0..<12, id: \.self) { i in
                let hot = (minutes / 5) % 12 == i
                Capsule()
                    .fill(hot ? Turf.floodlight : Turf.chalk.opacity(i.isMultiple(of: 3) ? 0.5 : 0.2))
                    .frame(width: 3, height: hot ? 30 : (i.isMultiple(of: 3) ? 20 : 12))
            }
        }
        .animation(.easeOut(duration: 0.12), value: minutes)
    }
}

struct FormatStep: View {
    @ObservedObject var draft: Draft

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Masthead(kicker: "\(draft.teams.count) teams", title: "How do we play?")

                ForEach(Format.allCases) { f in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            draft.format = f
                            draft.settleFormat()
                        }
                        Buzz.tick()
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            Text(f.emoji).font(.system(size: 30))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(f.title)
                                    .font(.banner(19))
                                    .foregroundColor(draft.format == f ? Turf.ink : Turf.chalk)
                                Text(f.pitch)
                                    .font(.copy(14))
                                    .foregroundColor(draft.format == f ? Turf.inkHaze : Turf.haze)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .flagCard(draft.format == f ? Turf.paper : Turf.pitch)
                    }
                    .buttonStyle(Squash())
                }

                if draft.format == .groups {
                    VStack(spacing: 4) {
                        Counter(title: "Groups", value: Binding(get: { draft.groupCount }, set: {
                            draft.groupCount = $0
                            draft.settleFormat()
                        }), range: 1...draft.maxGroups)
                        Divider().overlay(Turf.line)
                        Counter(title: "Go through per group", value: Binding(get: { draft.advance }, set: {
                            draft.advance = $0
                            draft.settleFormat()
                        }), range: (draft.groupCount == 1 ? 2 : 1)...max(2, draft.smallestGroup - 1))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .flagCard()
                }

                Forecast(draft: draft)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
        .onAppear { draft.settleFormat() }
    }
}

struct Forecast: View {
    @ObservedObject var draft: Draft

    var body: some View {
        let t = draft.forecast
        let ko = t.fixtures.filter(\.stage.isKnockout)
        let firstKO = ko.filter { $0.stage.kind == .knockout }.map(\.stage.round).max()

        HStack(spacing: 0) {
            stat("\(t.fixtures.count)", "matches")
            Rectangle().fill(Turf.line).frame(width: 1, height: 40)
            stat(firstKO.map { Stage(kind: .knockout, round: $0).roundName } ?? "Table", "playoff from")
            Rectangle().fill(Turf.line).frame(width: 1, height: 40)
            stat(t.finishTime.map { Clockface.time.string(from: $0) } ?? "—", "final whistle")
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Turf.chalk.opacity(0.3), style: StrokeStyle(lineWidth: 1.2, dash: [6, 5])))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.scoreboard(24))
                .foregroundColor(Turf.floodlight)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label.uppercased())
                .font(.copy(10, .heavy))
                .tracking(1.2)
                .foregroundColor(Turf.haze)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
    }
}

struct RulesStep: View {
    @ObservedObject var draft: Draft

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Masthead(kicker: "Referee's notebook", title: "House rules")
                RulesCard(rules: $draft.rules, format: draft.format)
                Text("Two yellows in the same match count as a red. Bans are served in the team's next fixtures and recalculate whenever a result is corrected.")
                    .font(.copy(13))
                    .foregroundColor(Turf.haze)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
    }
}

struct RulesCard: View {
    @Binding var rules: Rules
    let format: Format
    var lockBronze = false

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                if format != .knockout {
                    Counter(title: "Points for a win", value: $rules.win, range: 1...5)
                    Divider().overlay(Turf.line)
                    Counter(title: "Points for a draw", value: $rules.draw, range: 0...2)
                    Divider().overlay(Turf.line)
                }
                Counter(title: "🟨 Yellows to a ban", value: $rules.yellowLimit, range: 1...5)
                Divider().overlay(Turf.line)
                Counter(title: "🟥 Red card ban", value: $rules.redBan, range: 1...4, unit: rules.redBan == 1 ? " game" : " games")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .flagCard()

            if format != .league {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Level after full time in the playoff")
                        .font(.copy(15, .semibold))
                        .foregroundColor(Turf.haze)
                    HStack(spacing: 8) {
                        decider(.penalties, "🎯 Penalties")
                        decider(.goldenGoal, "✨ Golden goal")
                    }
                    Divider().overlay(Turf.line)
                    if lockBronze {
                        HStack {
                            Text("Third-place match")
                                .font(.copy(16, .bold))
                                .foregroundColor(Turf.chalk)
                            Spacer()
                            Text(rules.bronze ? "On · set at the draw" : "Off · set at the draw")
                                .font(.copy(13, .semibold))
                                .foregroundColor(Turf.haze)
                        }
                    } else {
                        ChalkSwitch(title: "Third-place match", detail: "Semi-final losers play for bronze.", isOn: $rules.bronze)
                    }
                }
                .padding(18)
                .flagCard()
            }
        }
    }

    private func decider(_ d: Rules.Decider, _ label: String) -> some View {
        Button {
            rules.decider = d
            Buzz.tick()
        } label: {
            Chip(text: label, on: rules.decider == d)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(Squash())
    }
}
