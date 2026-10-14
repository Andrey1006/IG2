import Foundation

enum Format: String, Codable, CaseIterable, Identifiable {
    case groups, league, knockout

    var id: String { rawValue }

    var title: String {
        switch self {
        case .groups: return "Groups + Playoff"
        case .league: return "League"
        case .knockout: return "Knockout"
        }
    }

    var pitch: String {
        switch self {
        case .groups: return "World Cup style: round-robin groups, then a bracket for the best."
        case .league: return "Everyone plays everyone once. Top of the table lifts the cup."
        case .knockout: return "Lose and you're out. Seeds skip the first round if numbers are odd."
        }
    }

    var emoji: String {
        switch self {
        case .groups: return "🗂️"
        case .league: return "📋"
        case .knockout: return "⚔️"
        }
    }
}

struct Rules: Codable, Equatable {
    enum Decider: String, Codable {
        case penalties, goldenGoal
    }

    var win = 3
    var draw = 1
    var yellowLimit = 2
    var redBan = 1
    var decider = Decider.penalties
    var bronze = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        win = try c.decodeIfPresent(Int.self, forKey: .win) ?? 3
        draw = try c.decodeIfPresent(Int.self, forKey: .draw) ?? 1
        yellowLimit = try c.decodeIfPresent(Int.self, forKey: .yellowLimit) ?? 2
        redBan = try c.decodeIfPresent(Int.self, forKey: .redBan) ?? 1
        decider = (try? c.decodeIfPresent(Decider.self, forKey: .decider)) ?? .penalties
        bronze = try c.decodeIfPresent(Bool.self, forKey: .bronze) ?? true
    }
}

struct Tournament: Codable, Identifiable {
    let id: UUID
    var name: String
    var start: Date
    var pitches: Int
    var matchMinutes: Int
    var breakMinutes: Int
    var format: Format
    var groupCount: Int
    var advance: Int
    var rules: Rules
    var teams: [Team]
    var groups: [[UUID]] = []
    var fixtures: [Fixture] = []

    var slotMinutes: Int { matchMinutes + breakMinutes }

    func team(_ id: UUID?) -> Team? {
        guard let id else { return nil }
        return teams.first { $0.id == id }
    }

    func fixture(_ id: UUID) -> Fixture? {
        fixtures.first { $0.id == id }
    }

    func roster(of player: UUID) -> (Player, Team)? {
        for t in teams {
            if let p = t.players.first(where: { $0.id == player }) { return (p, t) }
        }
        return nil
    }

    var played: Int { fixtures.filter { $0.status == .finished }.count }

    var finishTime: Date? {
        fixtures.map(\.kickoff).max().map { $0.addingTimeInterval(TimeInterval(matchMinutes * 60)) }
    }

    var isOver: Bool { !fixtures.isEmpty && fixtures.allSatisfy { $0.status == .finished } }
}

struct Honour: Codable, Identifiable {
    let id: UUID
    var name: String
    var date: Date
    var champion: String?
    var runnerUp: String?
    var topScorer: String?
    var topGoals: Int
    var teams: Int
    var fixtures: Int
    var goals: Int
}

struct Book: Codable {
    static let currentVersion = 1

    var version = Book.currentVersion
    var tournament: Tournament?
    var honours: [Honour] = []
    var haptics = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? Book.currentVersion
        tournament = try c.decodeIfPresent(Tournament.self, forKey: .tournament)
        honours = (try? c.decodeIfPresent([Honour].self, forKey: .honours)) ?? []
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
    }
}
