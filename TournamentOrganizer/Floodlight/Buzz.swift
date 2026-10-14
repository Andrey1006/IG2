import UIKit

enum Buzz {
    static var enabled = true

    static func tick() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func threshold() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.75)
    }

    static func deny() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func thud() {
        guard enabled else { return }
        let g = UIImpactFeedbackGenerator(style: .heavy)
        g.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { g.impactOccurred(intensity: 0.5) }
    }
}
