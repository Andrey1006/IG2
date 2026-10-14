import Foundation
import Combine

@MainActor
final class Draft: ObservableObject {
    enum Step: Int, CaseIterable {
        case event, format, squad, rules, draw

        var title: String {
            switch self {
            case .event: return "Matchday"
            case .format: return "Format"
            case .squad: return "Teams"
            case .rules: return "Rules"
            case .draw: return "The Draw"
            }
        }
    }

    @Published var step = Step.event
    @Published var name = Rehearsal.name
    @Published var day = Draft.firstKickoff().day
    @Published var clockMinutes = Draft.firstKickoff().minutes
    @Published var pitches = 2
    @Published var matchMinutes = 12
    @Published var breakMinutes = 3
    @Published var format = Format.groups
    @Published var groupCount = 2
    @Published var advance = 2
    @Published var rules = Rules()
    @Published var teams = Rehearsal.teams
    @Published var drawn: [Team] = []
    @Published var sampleResults = true

    private static let lateCall = 20 * 60
    private static let earlyCall = 8 * 60
    private static let usualKickoff = 10 * 60

    private static func firstKickoff() -> (day: Date, minutes: Int) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let c = cal.dateComponents([.hour, .minute], from: .now)
        let now = (c.hour ?? 10) * 60 + (c.minute ?? 0)
        if now < earlyCall { return (today, usualKickoff) }
        if now >= lateCall {
            return (cal.date(byAdding: .day, value: 1, to: today) ?? today, usualKickoff)
        }
        return (today, ((now + 29) / 30) * 30)
    }

    var start: Date {
        day.addingTimeInterval(TimeInterval(clockMinutes * 60))
    }

    var smallestGroup: Int {
        groupCount > 0 ? teams.count / groupCount : teams.count
    }

    var maxGroups: Int { max(1, min(8, teams.count / 2)) }

    func settleFormat() {
        groupCount = min(max(groupCount, 1), maxGroups)
        let cap = max(1, smallestGroup - 1)
        advance = min(max(advance, groupCount == 1 ? 2 : 1), cap)
        drawn.removeAll()
    }

    var squadIssue: String? {
        if teams.count < 4 { return "Add at least 4 teams." }
        if teams.count > 32 { return "32 teams is the ceiling for one organiser." }
        if teams.contains(where: { $0.name.trimmingCharacters(in: .whitespaces).isEmpty }) { return "Every team needs a name." }
        let names = teams.map { $0.name.trimmingCharacters(in: .whitespaces).lowercased() }
        if Set(names).count != names.count { return "Two teams share a name." }
        return nil
    }

    var formatIssue: String? {
        guard format == .groups else { return nil }
        if smallestGroup < 2 { return "Each group needs at least 2 teams." }
        if groupCount * advance < 2 { return "At least two teams must reach the playoff." }
        return nil
    }

    var eventIssue: String? {
        name.trimmingCharacters(in: .whitespaces).isEmpty ? "Give the tournament a name." : nil
    }

    func blueprint(order: [Team]) -> Tournament {
        var t = Tournament(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            start: start,
            pitches: pitches,
            matchMinutes: matchMinutes,
            breakMinutes: breakMinutes,
            format: format,
            groupCount: format == .groups ? groupCount : 1,
            advance: advance,
            rules: rules,
            teams: order.map { team in
                var copy = team
                copy.name = team.name.trimmingCharacters(in: .whitespaces)
                return copy
            }
        )
        t.seatGroups()
        t.layFixtures()
        return t
    }

    var forecast: Tournament { blueprint(order: teams) }

    var canRehearse: Bool { Rehearsal.untouched(teams) && format != .knockout }

    func build() -> Tournament {
        var t = blueprint(order: drawn)
        if sampleResults && canRehearse {
            Rehearsal.playOut(&t)
        }
        return t
    }
}
