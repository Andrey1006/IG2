import Foundation

extension Tournament {
    static func roundRobin(_ ids: [UUID]) -> [[(UUID, UUID)]] {
        var wheel: [UUID?] = ids
        if wheel.count % 2 == 1 { wheel.append(nil) }
        let n = wheel.count
        guard n >= 2 else { return [] }

        var rounds: [[(UUID, UUID)]] = []
        for r in 0..<(n - 1) {
            var pairs: [(UUID, UUID)] = []
            for i in 0..<(n / 2) {
                guard let a = wheel[i], let b = wheel[n - 1 - i] else { continue }
                pairs.append(r.isMultiple(of: 2) == (i == 0) ? (a, b) : (b, a))
            }
            rounds.append(pairs)
            let last = wheel.removeLast()
            wheel.insert(last, at: 1)
        }
        return rounds
    }

    static func seedOrder(_ size: Int) -> [Int] {
        var order = [1]
        while order.count < size {
            let next = order.count * 2 + 1
            order = order.flatMap { [$0, next - $0] }
        }
        return order
    }

    static func bracket(_ entrants: [Seat], bronze: Bool) -> [Fixture] {
        guard entrants.count >= 2 else { return [] }
        var size = 1
        while size < entrants.count { size *= 2 }

        var current: [Seat?] = seedOrder(size).map { $0 <= entrants.count ? entrants[$0 - 1] : nil }
        var round = size.trailingZeroBitCount
        var made: [Fixture] = []
        while current.count > 1 {
            var next: [Seat?] = []
            for k in 0..<(current.count / 2) {
                switch (current[2 * k], current[2 * k + 1]) {
                case let (a?, b?):
                    let f = Fixture(stage: Stage(kind: .knockout, round: round, index: k), home: a, away: b)
                    made.append(f)
                    next.append(.winner(f.id))
                case let (a, b):
                    next.append(a ?? b)
                }
            }
            current = next
            round -= 1
        }

        let semis = made.filter { $0.stage.kind == .knockout && $0.stage.round == 2 }
        if bronze, semis.count == 2 {
            made.append(Fixture(stage: Stage(kind: .bronze, round: 1), home: .loser(semis[0].id), away: .loser(semis[1].id)))
        }
        return made
    }

    func entrants() -> [Seat] {
        switch format {
        case .groups:
            return (1...max(advance, 1)).flatMap { rank in
                (0..<groups.count).map { Seat.place(group: $0, rank: rank) }
            }
        case .knockout:
            return teams.map { .team($0.id) }
        case .league:
            return []
        }
    }

    mutating func layFixtures() {
        var opening: [Fixture] = []
        switch format {
        case .groups:
            let rounds = groups.map { Tournament.roundRobin($0) }
            let depth = rounds.map(\.count).max() ?? 0
            for r in 0..<depth {
                for (g, list) in rounds.enumerated() where r < list.count {
                    for (h, a) in list[r] {
                        opening.append(Fixture(stage: Stage(kind: .group, group: g, round: r + 1), home: .team(h), away: .team(a)))
                    }
                }
            }
        case .league:
            for (r, list) in Tournament.roundRobin(teams.map(\.id)).enumerated() {
                for (h, a) in list {
                    opening.append(Fixture(stage: Stage(kind: .league, round: r + 1), home: .team(h), away: .team(a)))
                }
            }
        case .knockout:
            break
        }

        var slot = 0
        var placed: [Fixture] = []
        var lastBusy = Set<UUID>()
        var queue = opening
        let lookahead = max(pitches * 3, 4)

        while !queue.isEmpty {
            var busy = Set<UUID>()
            var used = 0
            for strict in [true, false] {
                var i = 0
                while i < min(queue.count, lookahead) && used < pitches {
                    let ids = [queue[i].home, queue[i].away].compactMap { seat -> UUID? in
                        if case .team(let id) = seat { return id }
                        return nil
                    }
                    let clash = ids.contains { busy.contains($0) }
                    let tired = strict && ids.contains { lastBusy.contains($0) }
                    if clash || tired {
                        i += 1
                        continue
                    }
                    var f = queue.remove(at: i)
                    f.pitch = used
                    f.kickoff = kickoffTime(slot)
                    placed.append(f)
                    busy.formUnion(ids)
                    used += 1
                }
            }
            lastBusy = busy
            slot += 1
        }

        let ko = format == .league ? [] : Tournament.bracket(entrants(), bronze: rules.bronze)
        let roundsDown = Set(ko.filter { $0.stage.kind == .knockout }.map(\.stage.round)).sorted(by: >)
        for round in roundsDown {
            var batch = ko.filter { $0.stage.kind == .knockout && $0.stage.round == round }
                .sorted { $0.stage.index < $1.stage.index }
            if round == 1 {
                let third = ko.filter { $0.stage.kind == .bronze }
                batch = pitches > 1 ? batch + third : third + batch
            }
            for (i, var f) in batch.enumerated() {
                f.pitch = i % pitches
                f.kickoff = kickoffTime(slot + i / pitches)
                placed.append(f)
            }
            slot += (batch.count + pitches - 1) / pitches
        }

        fixtures = placed
    }

    func kickoffTime(_ slot: Int) -> Date {
        start.addingTimeInterval(TimeInterval(slot * slotMinutes * 60))
    }

    mutating func seatGroups() {
        let g = format == .groups ? max(groupCount, 1) : 1
        var made = Array(repeating: [UUID](), count: g)
        for (i, t) in teams.enumerated() {
            made[i % g].append(t.id)
        }
        groups = format == .groups ? made : []
    }
}
