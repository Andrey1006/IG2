import Foundation
import Combine
import CoreMotion

final class ShakeSensor: ObservableObject {
    @Published private(set) var shakes = 0

    private let motion = CMMotionManager()
    private var last = Date.distantPast
    private let jolt = 2.1
    private let cooldown: TimeInterval = 0.3

    var available: Bool { motion.isAccelerometerAvailable }

    func start() {
        guard available, !motion.isAccelerometerActive else { return }
        motion.accelerometerUpdateInterval = 1 / 30
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let a = data?.acceleration else { return }
            let g = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
            let now = Date()
            if g > self.jolt, now.timeIntervalSince(self.last) > self.cooldown {
                self.last = now
                self.shakes += 1
            }
        }
    }

    func stop() {
        motion.stopAccelerometerUpdates()
    }
}
