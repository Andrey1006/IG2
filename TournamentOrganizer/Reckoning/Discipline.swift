import Foundation

struct Suspension: Identifiable {
    let player: Player
    let team: Team
    let matches: Int
    let reason: Incident.Kind

    var id: UUID { player.id }
}

struct Scorer: Identifiable {
    let player: Player
    let team: Team
    var goals: Int
    var matches: Int

    var id: UUID { player.id }
}

struct CardLine: Identifiable {
    let team: Team
    var yellows = 0
    var reds = 0

    var id: UUID { team.id }
    var points: Int { yellows + reds * 3 }
}

private struct Ledger {
    var banned: [UUID: Set<UUID>] = [:]
    var outstanding: [UUID: (Int, Incident.Kind)] = [:]
    var yellows: [UUID: Int] = [:]
}

extension Tournament {
    func fixtures(of team: UUID) -> [Fixture] {
        fixtures
            .filter { side(of: team, in: $0) != nil }
            .sorted { $0.kickoff < $1.kickoff }
    }

    private func ledger(for team: Team) -> Ledger {
        var book = Ledger()
        var pending: [UUID: (Int, Incident.Kind)] = [:]
        var snapshotTaken = false

        for f in fixtures(of: team.id) {
            guard let side = side(of: team.id, in: f) else { continue }
            if f.status == .scheduled && !snapshotTaken {
                book.outstanding = pending.filter { $0.value.0 > 0 }
                snapshotTaken = true
            }
            let out = Set(pending.filter { $0.value.0 > 0 }.keys)
            book.banned[f.id] = out
            for p in out {
                pending[p]?.0 -= 1
            }
            guard f.status != .scheduled else { continue }

            let mine = f.incidents.filter { $0.side == side && $0.kind.isCard }
            for p in Set(mine.compactMap(\.player)) {
                let y = mine.filter { $0.player == p && $0.kind == .yellow }.count
                let r = mine.filter { $0.player == p && $0.kind == .red }.count
                if r > 0 || y >= 2 {
                    pending[p] = ((pending[p]?.0 ?? 0) + rules.redBan, .red)
                } else if y == 1 {
                    let total = (book.yellows[p] ?? 0) + 1
                    book.yellows[p] = total
                    if total % max(rules.yellowLimit, 1) == 0 {
                        pending[p] = ((pending[p]?.0 ?? 0) + 1, .yellow)
                    }
                }
            }
        }
        if !snapshotTaken && !isOver {
            book.outstanding = pending.filter { $0.value.0 > 0 }
        }
        return book
    }

    func unavailable(in f: Fixture, side: Side) -> Set<UUID> {
        guard let t = team(at: f.seat(side)) else { return [] }
        return ledger(for: t).banned[f.id] ?? []
    }

    var suspensions: [Suspension] {
        teams.flatMap { t -> [Suspension] in
            ledger(for: t).outstanding.compactMap { id, value in
                guard let p = t.players.first(where: { $0.id == id }) else { return nil }
                return Suspension(player: p, team: t, matches: value.0, reason: value.1)
            }
        }
        .sorted { $0.matches == $1.matches ? $0.player.name < $1.player.name : $0.matches > $1.matches }
    }

    var onTheBrink: [(Player, Team, Int)] {
        guard rules.yellowLimit > 1, !isOver else { return [] }
        let out = Set(suspensions.map(\.id))
        return teams.flatMap { t -> [(Player, Team, Int)] in
            ledger(for: t).yellows.compactMap { id, n in
                guard n % rules.yellowLimit == rules.yellowLimit - 1, !out.contains(id),
                      let p = t.players.first(where: { $0.id == id }) else { return nil }
                return (p, t, n)
            }
        }
        .sorted { $0.0.name < $1.0.name }
    }

    var scorers: [Scorer] {
        var table: [UUID: Scorer] = [:]
        for f in fixtures where f.status != .scheduled {
            for i in f.incidents where i.kind == .goal {
                guard let pid = i.player, let (p, t) = roster(of: pid) else { continue }
                table[pid, default: Scorer(player: p, team: t, goals: 0, matches: 0)].goals += 1
            }
        }
        for id in table.keys {
            guard let t = table[id]?.team else { continue }
            table[id]?.matches = fixtures(of: t.id).filter { $0.status != .scheduled }.count
        }
        return table.values.sorted {
            if $0.goals != $1.goals { return $0.goals > $1.goals }
            if $0.matches != $1.matches { return $0.matches < $1.matches }
            return $0.player.name < $1.player.name
        }
    }

    var cardTable: [CardLine] {
        var lines = Dictionary(uniqueKeysWithValues: teams.map { ($0.id, CardLine(team: $0)) })
        for f in fixtures where f.status != .scheduled {
            for i in f.incidents where i.kind.isCard {
                guard let tid = resolve(f.seat(i.side)) else { continue }
                if i.kind == .yellow { lines[tid]?.yellows += 1 } else { lines[tid]?.reds += 1 }
            }
        }
        return lines.values
            .filter { $0.points > 0 }
            .sorted { $0.points == $1.points ? $0.team.name < $1.team.name : $0.points < $1.points }
    }

    var totalGoals: Int {
        fixtures.filter { $0.status != .scheduled }.reduce(0) { $0 + $1.goals(.home) + $1.goals(.away) }
    }

    func log(of player: UUID) -> [(Fixture, [Incident])] {
        fixtures
            .filter { $0.status != .scheduled }
            .sorted { $0.kickoff < $1.kickoff }
            .compactMap { f in
                let mine = f.incidents.filter { $0.player == player }
                return mine.isEmpty ? nil : (f, mine)
            }
    }
}
