import Foundation

extension Tournament {
    func resolve(_ seat: Seat) -> UUID? {
        switch seat {
        case .team(let id):
            return id
        case .place(let group, let rank):
            guard isComplete(group: group) else { return nil }
            let rows = table(group: group)
            return rows.indices.contains(rank - 1) ? rows[rank - 1].team.id : nil
        case .winner(let fid):
            guard let f = fixture(fid), let side = f.winningSide else { return nil }
            return resolve(f.seat(side))
        case .loser(let fid):
            guard let f = fixture(fid), let side = f.winningSide else { return nil }
            return resolve(f.seat(side.other))
        }
    }

    func team(at seat: Seat) -> Team? { team(resolve(seat)) }

    func side(of team: UUID, in f: Fixture) -> Side? {
        if resolve(f.home) == team { return .home }
        if resolve(f.away) == team { return .away }
        return nil
    }

    func label(_ seat: Seat) -> String {
        if let t = team(at: seat) { return t.name }
        switch seat {
        case .team: return "TBD"
        case .place(let group, let rank):
            let g = Stage.letter(group)
            switch rank {
            case 1: return "Winner \(g)"
            case 2: return "Runner-up \(g)"
            default: return "\(rank.ordinal) \(g)"
            }
        case .winner(let fid):
            return "Winner \(fixture(fid)?.stage.code ?? "")"
        case .loser(let fid):
            return "Loser \(fixture(fid)?.stage.code ?? "")"
        }
    }

    func isReady(_ f: Fixture) -> Bool {
        resolve(f.home) != nil && resolve(f.away) != nil
    }

    var final: Fixture? {
        fixtures.first { $0.stage.kind == .knockout && $0.stage.round == 1 }
    }

    var podium: (champion: Team?, runnerUp: Team?) {
        if format == .league {
            guard isComplete(group: nil) else { return (nil, nil) }
            let rows = table(group: nil)
            return (rows.first?.team, rows.dropFirst().first?.team)
        }
        guard let f = final, let side = f.winningSide else { return (nil, nil) }
        return (team(at: f.seat(side)), team(at: f.seat(side.other)))
    }

    func displaced(after edited: Tournament) -> [String] {
        edited.fixtures.compactMap { f in
            guard let origin = f.origin else { return nil }
            var swaps: [String] = []
            for (frozen, seat) in [(f.home, origin.home), (f.away, origin.away)] {
                guard case .team(let played) = frozen,
                      let now = edited.resolve(seat), now != played else { continue }
                swaps.append("\(edited.team(played)?.name ?? "?") → \(edited.team(now)?.name ?? "?")")
            }
            guard !swaps.isEmpty else { return nil }
            return "\(f.stage.title): " + swaps.joined(separator: ", ")
        }
    }
}
