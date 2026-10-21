import Foundation

struct Player: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var number: Int?

    init(id: UUID = UUID(), name: String, number: Int? = nil) {
        self.id = id
        self.name = name
        self.number = number
    }

    var shortName: String {
        let parts = name.split(separator: " ")
        guard parts.count > 1, let first = parts.first?.first else { return name }
        return "\(first). \(parts.dropFirst().joined(separator: " "))"
    }
}

struct Team: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var kit: Int
    var seeded: Bool
    var players: [Player]
    var crest: Data?

    init(id: UUID = UUID(), name: String, kit: Int, seeded: Bool = false, players: [Player] = [], crest: Data? = nil) {
        self.id = id
        self.name = name
        self.kit = kit
        self.seeded = seeded
        self.players = players
        self.crest = crest
    }

    var code: String {
        let word = name.split(separator: " ").first.map(String.init) ?? name
        return String(word.prefix(3)).uppercased()
    }
}

extension Int {
    var ordinal: String {
        let tens = (self / 10) % 10
        guard tens != 1 else { return "\(self)th" }
        switch self % 10 {
        case 1: return "\(self)st"
        case 2: return "\(self)nd"
        case 3: return "\(self)rd"
        default: return "\(self)th"
        }
    }
}
