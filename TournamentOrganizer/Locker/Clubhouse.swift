import Foundation
import Combine

@MainActor
final class Clubhouse: ObservableObject {
    @Published private(set) var book: Book {
        didSet { persist() }
    }

    private let d: UserDefaults
    private static let key = "majorball.book"

    init(defaults: UserDefaults = .standard) {
        d = defaults
        if let data = d.data(forKey: Clubhouse.key),
           let stored = try? JSONDecoder().decode(Book.self, from: data) {
            book = stored
        } else {
            book = Book()
        }
        Buzz.enabled = book.haptics
    }

    var tournament: Tournament? { book.tournament }

    private func persist() {
        guard let data = try? JSONEncoder().encode(book) else { return }
        d.set(data, forKey: Clubhouse.key)
    }

    func open(_ t: Tournament) {
        book.tournament = t
    }

    func edit(_ change: (inout Tournament) -> Void) {
        guard var t = book.tournament else { return }
        change(&t)
        book.tournament = t
    }

    func editFixture(_ id: UUID, _ change: (inout Fixture) -> Void) {
        edit { t in
            guard let i = t.fixtures.firstIndex(where: { $0.id == id }) else { return }
            change(&t.fixtures[i])
        }
    }

    func kickOff(_ id: UUID) {
        edit { t in
            guard let i = t.fixtures.firstIndex(where: { $0.id == id }),
                  let h = t.resolve(t.fixtures[i].home),
                  let a = t.resolve(t.fixtures[i].away) else { return }
            var f = t.fixtures[i]
            if f.stage.isKnockout && f.origin == nil {
                f.origin = .init(home: f.home, away: f.away)
            }
            f.home = .team(h)
            f.away = .team(a)
            f.status = .live
            f.clock.start()
            t.fixtures[i] = f
        }
    }

    @discardableResult
    func record(_ incident: Incident, in id: UUID) -> Bool {
        var settled = false
        editFixture(id) { f in
            f.incidents.append(incident)
            f.incidents.sort { $0.minute < $1.minute }
            if f.goldenGoal, incident.kind == .goal || incident.kind == .ownGoal, !f.isTied {
                f.clock.stop()
                f.status = .finished
                settled = true
            }
        }
        return settled
    }

    func strike(_ incident: UUID, in id: UUID) {
        editFixture(id) { $0.incidents.removeAll { $0.id == incident } }
    }

    func amend(_ incident: Incident, in id: UUID) {
        editFixture(id) { f in
            guard let i = f.incidents.firstIndex(where: { $0.id == incident.id }) else { return }
            f.incidents[i] = incident
        }
    }

    func fullTime(_ id: UUID, shootout: Shootout? = nil) {
        editFixture(id) { f in
            f.clock.stop()
            f.shootout = shootout
            f.goldenGoal = false
            f.status = .finished
        }
    }

    func shiftPitch(_ pitch: Int, minutes: Int) {
        edit { t in
            for i in t.fixtures.indices where t.fixtures[i].pitch == pitch && t.fixtures[i].status == .scheduled {
                t.fixtures[i].kickoff.addTimeInterval(TimeInterval(minutes * 60))
            }
        }
    }

    func replace(_ t: Tournament) {
        book.tournament = t
    }

    func addPlayer(_ name: String, number: Int?, to team: UUID) -> Player? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let p = Player(name: trimmed, number: number)
        edit { t in
            guard let i = t.teams.firstIndex(where: { $0.id == team }) else { return }
            t.teams[i].players.append(p)
        }
        return p
    }

    func setHaptics(_ on: Bool) {
        book.haptics = on
        Buzz.enabled = on
    }

    func closeTournament() {
        guard let t = book.tournament else { return }
        let podium = t.podium
        let top = t.scorers.first
        book.honours.insert(
            Honour(
                id: t.id,
                name: t.name,
                date: t.start,
                champion: podium.champion?.name,
                runnerUp: podium.runnerUp?.name,
                topScorer: top.map { "\($0.player.name) (\($0.team.code))" },
                topGoals: top?.goals ?? 0,
                teams: t.teams.count,
                fixtures: t.played,
                goals: t.totalGoals
            ),
            at: 0
        )
        book.tournament = nil
    }

    func clearScoresheet() {
        edit { t in
            for i in t.fixtures.indices {
                var f = t.fixtures[i]
                if let o = f.origin {
                    f.home = o.home
                    f.away = o.away
                    f.origin = nil
                }
                f.incidents = []
                f.status = .scheduled
                f.clock = Stopwatch()
                f.shootout = nil
                f.goldenGoal = false
                t.fixtures[i] = f
            }
        }
    }

    func packUp() {
        d.removeObject(forKey: Clubhouse.key)
        book = Book()
        Buzz.enabled = true
    }
}
