import Foundation

enum Side: String, Codable, CaseIterable {
    case home, away

    var other: Side { self == .home ? .away : .home }
}

struct Stage: Codable, Hashable {
    enum Kind: String, Codable {
        case group, league, knockout, bronze
    }

    var kind: Kind
    var group = 0
    var round: Int
    var index = 0

    var isKnockout: Bool { kind == .knockout || kind == .bronze }

    var roundName: String {
        switch kind {
        case .group: return "Round \(round)"
        case .league: return "Matchday \(round)"
        case .bronze: return "Third place"
        case .knockout:
            switch round {
            case 1: return "Final"
            case 2: return "Semi-finals"
            case 3: return "Quarter-finals"
            default: return "Round of \(1 << round)"
            }
        }
    }

    var title: String {
        switch kind {
        case .group: return "Group \(Stage.letter(group)) · R\(round)"
        case .league: return "Matchday \(round)"
        case .bronze: return "Third place"
        case .knockout:
            switch round {
            case 1: return "Final"
            case 2: return "Semi-final \(index + 1)"
            case 3: return "Quarter-final \(index + 1)"
            default: return "Round of \(1 << round) · \(index + 1)"
            }
        }
    }

    var code: String {
        switch kind {
        case .group: return "\(Stage.letter(group))\(round)"
        case .league: return "MD\(round)"
        case .bronze: return "3RD"
        case .knockout:
            switch round {
            case 1: return "F"
            case 2: return "SF\(index + 1)"
            case 3: return "QF\(index + 1)"
            default: return "R\(1 << round)-\(index + 1)"
            }
        }
    }

    static func letter(_ group: Int) -> String {
        String(UnicodeScalar(UInt8(65 + group % 26)))
    }

    static func pitchName(_ pitch: Int) -> String { letter(pitch) }
}

enum Seat: Codable, Hashable {
    case team(UUID)
    case place(group: Int, rank: Int)
    case winner(UUID)
    case loser(UUID)
}

struct Incident: Codable, Identifiable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case goal, ownGoal, yellow, red

        var emoji: String {
            switch self {
            case .goal: return "⚽️"
            case .ownGoal: return "🥅"
            case .yellow: return "🟨"
            case .red: return "🟥"
            }
        }

        var label: String {
            switch self {
            case .goal: return "Goal"
            case .ownGoal: return "Own goal"
            case .yellow: return "Yellow"
            case .red: return "Red"
            }
        }

        var isCard: Bool { self == .yellow || self == .red }
    }

    let id: UUID
    var kind: Kind
    var minute: Int
    var side: Side
    var player: UUID?

    init(id: UUID = UUID(), kind: Kind, minute: Int, side: Side, player: UUID?) {
        self.id = id
        self.kind = kind
        self.minute = minute
        self.side = side
        self.player = player
    }

    var creditedSide: Side { kind == .ownGoal ? side.other : side }
}

struct Stopwatch: Codable, Hashable {
    var banked: TimeInterval = 0
    var since: Date?

    var running: Bool { since != nil }

    func elapsed(at now: Date) -> TimeInterval {
        banked + (since.map { now.timeIntervalSince($0) } ?? 0)
    }

    func minute(at now: Date) -> Int {
        Int(elapsed(at: now) / 60) + 1
    }

    mutating func start(_ now: Date = .now) {
        if since == nil { since = now }
    }

    mutating func stop(_ now: Date = .now) {
        banked = elapsed(at: now)
        since = nil
    }
}

struct Shootout: Codable, Hashable {
    var home: Int
    var away: Int
}

struct Fixture: Codable, Identifiable, Hashable {
    enum Status: String, Codable {
        case scheduled, live, finished
    }

    struct Origin: Codable, Hashable {
        var home: Seat
        var away: Seat
    }

    let id: UUID
    var stage: Stage
    var pitch: Int
    var kickoff: Date
    var home: Seat
    var away: Seat
    var origin: Origin?
    var status: Status = .scheduled
    var incidents: [Incident] = []
    var clock = Stopwatch()
    var shootout: Shootout?
    var goldenGoal = false

    init(id: UUID = UUID(), stage: Stage, pitch: Int = 0, kickoff: Date = .now, home: Seat, away: Seat) {
        self.id = id
        self.stage = stage
        self.pitch = pitch
        self.kickoff = kickoff
        self.home = home
        self.away = away
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        stage = try c.decode(Stage.self, forKey: .stage)
        pitch = try c.decodeIfPresent(Int.self, forKey: .pitch) ?? 0
        kickoff = try c.decode(Date.self, forKey: .kickoff)
        home = try c.decode(Seat.self, forKey: .home)
        away = try c.decode(Seat.self, forKey: .away)
        origin = try c.decodeIfPresent(Origin.self, forKey: .origin)
        status = try c.decodeIfPresent(Status.self, forKey: .status) ?? .scheduled
        incidents = try c.decodeIfPresent([Incident].self, forKey: .incidents) ?? []
        clock = try c.decodeIfPresent(Stopwatch.self, forKey: .clock) ?? Stopwatch()
        shootout = try c.decodeIfPresent(Shootout.self, forKey: .shootout)
        goldenGoal = try c.decodeIfPresent(Bool.self, forKey: .goldenGoal) ?? false
    }

    func goals(_ side: Side) -> Int {
        incidents.filter { ($0.kind == .goal || $0.kind == .ownGoal) && $0.creditedSide == side }.count
    }

    func seat(_ side: Side) -> Seat { side == .home ? home : away }

    var isTied: Bool { goals(.home) == goals(.away) }

    var winningSide: Side? {
        guard status == .finished else { return nil }
        let h = goals(.home), a = goals(.away)
        if h != a { return h > a ? .home : .away }
        guard let s = shootout, s.home != s.away else { return nil }
        return s.home > s.away ? .home : .away
    }
}
