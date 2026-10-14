import SwiftUI

struct ChalkField: View {
    let placeholder: String
    @Binding var text: String
    var size: CGFloat = 17
    var keyboard: UIKeyboardType = .default
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.copy(size))
                    .foregroundColor(Turf.haze.opacity(0.55))
            }
            TextField("", text: $text)
                .font(.copy(size, .semibold))
                .foregroundColor(Turf.chalk)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .focused($focused)
                .tint(Turf.floodlight)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Turf.night.opacity(0.55)))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(focused ? Turf.floodlight : Turf.chalk.opacity(0.18))
                .frame(height: focused ? 2 : 1)
                .padding(.horizontal, 12)
                .animation(.easeOut(duration: 0.2), value: focused)
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }
}

struct Counter: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1
    var unit = ""

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.copy(15, .semibold))
                .foregroundColor(Turf.haze)
            Spacer(minLength: 4)
            nudge("minus", enabled: value - step >= range.lowerBound) { value -= step }
            Text("\(value)\(unit)")
                .font(.scoreboard(26))
                .foregroundColor(Turf.chalk)
                .frame(minWidth: 62)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: value)
            nudge("plus", enabled: value + step <= range.upperBound) { value += step }
        }
        .padding(.vertical, 6)
    }

    private func nudge(_ symbol: String, enabled: Bool, _ act: @escaping () -> Void) -> some View {
        Button {
            guard enabled else {
                Buzz.deny()
                return
            }
            act()
            Buzz.tick()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(enabled ? Turf.ink : Turf.haze.opacity(0.5))
                .frame(width: 36, height: 36)
                .background(Circle().fill(enabled ? Turf.chalk : Turf.stripe))
        }
        .buttonStyle(Squash())
    }
}

struct ChalkSwitch: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { isOn.toggle() }
            Buzz.tick()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.copy(16, .bold))
                        .foregroundColor(Turf.chalk)
                    if let detail {
                        Text(detail)
                            .font(.copy(13))
                            .foregroundColor(Turf.haze)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer()
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? Turf.floodlight : Turf.night)
                        .overlay(Capsule().stroke(Turf.chalk.opacity(0.2), lineWidth: 1))
                        .frame(width: 54, height: 30)
                    Text(isOn ? "⚽️" : "")
                        .font(.system(size: 15))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(isOn ? Turf.chalk : Turf.haze.opacity(0.6)))
                        .padding(3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ChalkTabs<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.0) { value, label in
                Button {
                    guard selection != value else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { selection = value }
                    Buzz.tick()
                } label: {
                    Text(label)
                        .font(.copy(14, .heavy))
                        .foregroundColor(selection == value ? Turf.ink : Turf.haze)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background {
                            if selection == value {
                                Capsule().fill(Turf.chalk).matchedGeometryEffect(id: "pill", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Turf.night.opacity(0.7)))
        .overlay(Capsule().stroke(Turf.line, lineWidth: 1))
    }
}

struct Chip: View {
    let text: String
    var on = false
    var tint = Turf.floodlight

    var body: some View {
        Text(text)
            .font(.copy(14, .bold))
            .foregroundColor(on ? Turf.ink : Turf.chalk)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Capsule().fill(on ? tint : Turf.night.opacity(0.6)))
            .overlay(Capsule().stroke(on ? tint : Turf.line, lineWidth: 1))
    }
}

struct Kit: View {
    let index: Int
    var size: CGFloat = 14

    var body: some View {
        ZStack {
            Circle().fill(Turf.kit(index))
            Rectangle()
                .fill(.black.opacity(0.18))
                .frame(width: size * 0.22)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Turf.chalk.opacity(0.35), lineWidth: 1))
    }
}

struct EmptyPitch: View {
    let art: Artwork
    let title: String
    let message: String
    var action: (String, () -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Art(art: art, height: 150)
            Text(title)
                .font(.banner(22))
                .foregroundColor(Turf.chalk)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.copy(15))
                .foregroundColor(Turf.haze)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let action {
                Button(action.0, action: action.1)
                    .buttonStyle(ChalkLineButton(tint: Turf.floodlight))
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
    }
}

struct Masthead: View {
    let kicker: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(kicker.uppercased())
                .font(.copy(12, .heavy))
                .tracking(2.2)
                .foregroundColor(Turf.floodlight)
            Text(title)
                .font(.banner(32))
                .foregroundColor(Turf.chalk)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionLabel: View {
    let text: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(text.uppercased())
                .font(.copy(12, .heavy))
                .tracking(1.8)
                .foregroundColor(Turf.haze)
                .lineLimit(1)
                .fixedSize()
            Rectangle().fill(Turf.line).frame(height: 1)
            if let trailing {
                Text(trailing)
                    .font(.tally(12))
                    .foregroundColor(Turf.haze)
            }
        }
    }
}

enum Clockface {
    static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    static let day: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f
    }()

    static func stopwatch(_ s: TimeInterval) -> String {
        let total = max(Int(s), 0)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
