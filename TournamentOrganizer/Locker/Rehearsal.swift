import Foundation

enum Rehearsal {
    static let name = "Friday Office Cup"

    private static func pinned(_ team: UInt8, _ player: UInt8 = 0) -> UUID {
        UUID(uuid: (0x4D, 0x42, 0x41, 0x4C, 0x4C, 0x00, 0x40, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, team, player))
    }

    private static let squads: [(String, Int, Bool, [String])] = [
        ("Dev FC", 1, true, ["Max Orlov", "Tim Becker", "Ravi Shah", "Leo Marsh", "Nika Dorn", "Sam Price"]),
        ("Sales Dynamo", 0, true, ["Chris Vane", "Oleg Brand", "Tara Quinn", "Jake Ruiz", "Dan Holt", "Mia Clarke"]),
        ("Accounting United", 3, false, ["Paul Weir", "Iris Lund", "Ben Koval", "Greg Moss", "Ana Silva", "Ed Fenn"]),
        ("HR Rangers", 6, false, ["Kate Bloom", "Rob Stein", "Yuri Lenz", "Jo Park", "Matt Doyle", "Lily Haas"]),
        ("Logistics Athletic", 4, false, ["Vic Cole", "Ivan Petrov", "Nate Ross", "Omar Said", "Pete Lyle", "Zoe Hart"]),
        ("Marketing City", 8, false, ["Ella Frost", "Noah Reid", "Kai Brenner", "Luke Abbot", "Sara Lind", "Theo Black"]),
        ("Support Wanderers", 5, false, ["Gus Novak", "Fay Moreno", "Ilya Sorin", "Ray Burke", "Ben Tate", "Cleo Ash"]),
        ("Legal Albion", 7, false, ["Hugo Lane", "Vera Kim", "Alan Pike", "Dima Frey", "Rose Vale", "Joel Hunt"])
    ]

    static var teams: [Team] {
        squads.enumerated().map { i, s in
            Team(
                id: pinned(UInt8(i + 1)),
                name: s.0,
                kit: s.1,
                seeded: s.2,
                players: s.3.enumerated().map { j, n in
                    Player(id: pinned(UInt8(i + 1), UInt8(j + 1)), name: n, number: [1, 4, 7, 9, 10, 11][j])
                }
            )
        }
    }

    static func untouched(_ teams: [Team]) -> Bool {
        let base = Set(Rehearsal.teams.map(\.id))
        return teams.count == base.count && Set(teams.map(\.id)) == base
            && teams.allSatisfy { !$0.players.isEmpty }
    }

    static func playOut(_ t: inout Tournament) {
        var rng = Dice(seed: 0x4D414A4F52)
        let staged = t.fixtures.indices
            .filter { [.group, .league].contains(t.fixtures[$0].stage.kind) && t.fixtures[$0].stage.round <= 2 }
            .sorted { t.fixtures[$0].kickoff < t.fixtures[$1].kickoff }
        let mins = t.matchMinutes

        for (n, i) in staged.enumerated() {
            var f = t.fixtures[i]
            guard let home = t.team(at: f.home), let away = t.team(at: f.away) else { continue }
            var log: [Incident] = []

            func minute() -> Int { rng.int(in: 1...mins) }
            func pick(_ team: Team) -> UUID? {
                guard team.players.count > 1 else { return team.players.first?.id }
                return team.players[rng.int(in: 1...(team.players.count - 1))].id
            }

            if n == 0, let star = home.players.dropFirst(3).first {
                for _ in 0..<3 { log.append(Incident(kind: .goal, minute: minute(), side: .home, player: star.id)) }
                log.append(Incident(kind: .goal, minute: minute(), side: .away, player: pick(away)))
            } else {
                for _ in 0..<[0, 1, 1, 2, 2, 3][rng.int(in: 0...5)] {
                    log.append(Incident(kind: .goal, minute: minute(), side: .home, player: pick(home)))
                }
                for _ in 0..<[0, 0, 1, 1, 2, 3][rng.int(in: 0...5)] {
                    log.append(Incident(kind: .goal, minute: minute(), side: .away, player: pick(away)))
                }
            }
            if rng.int(in: 0...3) == 0 {
                log.append(Incident(kind: .ownGoal, minute: minute(), side: .away, player: pick(away)))
            }
            if rng.int(in: 0...1) == 0 {
                let side: Side = rng.int(in: 0...1) == 0 ? .home : .away
                log.append(Incident(kind: .yellow, minute: minute(), side: side, player: pick(side == .home ? home : away)))
            }
            if n == staged.count - 1 {
                log.append(Incident(kind: .red, minute: max(mins - 2, 1), side: .away, player: away.players.dropFirst(1).first?.id))
            }
            if n == 1 || n == staged.count - 2, let culprit = home.players.dropFirst(2).first {
                log.append(Incident(kind: .yellow, minute: minute(), side: .home, player: culprit.id))
            }

            f.incidents = log.sorted { $0.minute < $1.minute }
            f.status = .finished
            f.clock = Stopwatch(banked: TimeInterval(mins * 60), since: nil)
            t.fixtures[i] = f
        }
    }
}

struct Dice {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }
}
