import Foundation

struct StandingRow: Identifiable {
    let team: Team
    var played = 0
    var won = 0
    var drawn = 0
    var lost = 0
    var scored = 0
    var conceded = 0
    var points = 0
    var fairPlay = 0
    var form: [Character] = []

    var id: UUID { team.id }
    var diff: Int { scored - conceded }
}

extension Tournament {
    func groupFixtures(_ group: Int?) -> [Fixture] {
        fixtures.filter { f in
            if let group { return f.stage.kind == .group && f.stage.group == group }
            return f.stage.kind == .league
        }
    }

    func isComplete(group: Int?) -> Bool {
        let list = groupFixtures(group)
        return !list.isEmpty && list.allSatisfy { $0.status == .finished }
    }

    func table(group: Int?) -> [StandingRow] {
        let members = group.map { groups.indices.contains($0) ? groups[$0] : [] } ?? teams.map(\.id)
        let played = groupFixtures(group)
            .filter { $0.status == .finished }
            .sorted { $0.kickoff < $1.kickoff }
        let order = Dictionary(uniqueKeysWithValues: teams.enumerated().map { ($1.id, $0) })

        var rows: [UUID: StandingRow] = [:]
        for id in members {
            if let t = team(id) { rows[id] = StandingRow(team: t) }
        }
        tally(played, into: &rows)

        let byPoints = Dictionary(grouping: rows.values, by: \.points)
        var ranked: [StandingRow] = []
        for pts in byPoints.keys.sorted(by: >) {
            let level = byPoints[pts] ?? []
            guard level.count > 1 else {
                ranked += level
                continue
            }
            let ids = Set(level.map(\.id))
            var mini: [UUID: StandingRow] = [:]
            for row in level { mini[row.id] = StandingRow(team: row.team) }
            tally(played.filter { f in
                guard case .team(let h) = f.home, case .team(let a) = f.away else { return false }
                return ids.contains(h) && ids.contains(a)
            }, into: &mini)

            ranked += level.sorted { l, r in
                let ml = mini[l.id], mr = mini[r.id]
                if ml?.points != mr?.points { return (ml?.points ?? 0) > (mr?.points ?? 0) }
                if ml?.diff != mr?.diff { return (ml?.diff ?? 0) > (mr?.diff ?? 0) }
                if l.diff != r.diff { return l.diff > r.diff }
                if l.scored != r.scored { return l.scored > r.scored }
                if l.fairPlay != r.fairPlay { return l.fairPlay < r.fairPlay }
                return (order[l.id] ?? 0) < (order[r.id] ?? 0)
            }
        }
        return ranked
    }

    private func tally(_ list: [Fixture], into rows: inout [UUID: StandingRow]) {
        for f in list {
            guard case .team(let h) = f.home, case .team(let a) = f.away,
                  rows[h] != nil, rows[a] != nil else { continue }
            let hg = f.goals(.home), ag = f.goals(.away)
            for (id, side, mine, theirs) in [(h, Side.home, hg, ag), (a, Side.away, ag, hg)] {
                guard var row = rows[id] else { continue }
                row.played += 1
                row.scored += mine
                row.conceded += theirs
                if mine > theirs {
                    row.won += 1
                    row.points += rules.win
                    row.form.append("W")
                } else if mine == theirs {
                    row.drawn += 1
                    row.points += rules.draw
                    row.form.append("D")
                } else {
                    row.lost += 1
                    row.form.append("L")
                }
                row.fairPlay += f.incidents.filter { $0.side == side && $0.kind == .yellow }.count
                row.fairPlay += f.incidents.filter { $0.side == side && $0.kind == .red }.count * 3
                rows[id] = row
            }
        }
    }
}
