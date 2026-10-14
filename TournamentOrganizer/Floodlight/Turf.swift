import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

enum Turf {
    static let night = Color(hex: 0x17191B)
    static let pitch = Color(hex: 0x232629)
    static let stripe = Color(hex: 0x2E3236)
    static let chalk = Color(hex: 0xF0F0EC)
    static let haze = Color(hex: 0x9EA3A8)
    static let floodlight = Color(hex: 0xFFB805)
    static let booking = Color(hex: 0xFFD60A)
    static let dismissal = Color(hex: 0xE5383B)

    static let paper = Color(hex: 0xECE6D3)
    static let paperShade = Color(hex: 0xDCD3BB)
    static let ink = Color(hex: 0x16181A)
    static let inkHaze = Color(hex: 0x5C6166)
    static let inkGold = Color(hex: 0x8A6A00)
    static let inkRed = Color(hex: 0xB0201F)

    static let line = chalk.opacity(0.12)
    static let column: CGFloat = 700

    static let kits: [UInt32] = [
        0xE5383B, 0x3A86FF, 0xF5D547, 0xF4F4F0, 0xFB8500, 0x9B5DE5,
        0x06D6A0, 0x22262A, 0xFF70A6, 0x8AC926, 0x8D99AE, 0x7B2D26
    ]

    static func kit(_ index: Int) -> Color {
        Color(hex: kits[((index % kits.count) + kits.count) % kits.count])
    }
}

extension Font {
    static func scoreboard(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.compressed).monospacedDigit()
    }

    static func banner(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    static func copy(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func tally(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct Mown: View {
    var bands = 9
    var drift: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width / CGFloat(bands)
            ZStack(alignment: .leading) {
                Turf.night
                ForEach(0..<(bands + 2), id: \.self) { i in
                    if i.isMultiple(of: 2) {
                        Rectangle()
                            .fill(Turf.stripe.opacity(0.35))
                            .frame(width: w)
                            .offset(x: CGFloat(i - 1) * w + drift.truncatingRemainder(dividingBy: w * 2))
                    }
                }
            }
        }
        .clipped()
    }
}
