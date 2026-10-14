import SwiftUI

struct KickoffFlow: View {
    @EnvironmentObject private var club: Clubhouse
    @StateObject private var draft = Draft()
    @State private var forward = true

    var body: some View {
        ZStack {
            Mown(bands: 7).ignoresSafeArea()

            VStack(spacing: 0) {
                TouchLine(step: draft.step)
                    .padding(.horizontal, 22)
                    .padding(.top, 10)

                ZStack {
                    page
                        .id(draft.step)
                        .transition(.asymmetric(
                            insertion: .offset(x: forward ? 60 : -60).combined(with: .opacity),
                            removal: .offset(x: forward ? -60 : 60).combined(with: .opacity)
                        ))
                }
                .frame(maxHeight: .infinity)

                footer
            }
            .frame(maxWidth: 640)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var page: some View {
        switch draft.step {
        case .event: EventStep(draft: draft)
        case .format: FormatStep(draft: draft)
        case .squad: SquadStep(draft: draft)
        case .rules: RulesStep(draft: draft)
        case .draw: DrawStep(draft: draft)
        }
    }

    private var issue: String? {
        switch draft.step {
        case .event: return draft.eventIssue
        case .format: return draft.formatIssue
        case .squad: return draft.squadIssue ?? draft.formatIssue
        case .rules: return nil
        case .draw: return draft.drawn.count == draft.teams.count ? nil : "Pull every ball out of the bowl."
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if let issue {
                Text(issue)
                    .font(.copy(13, .semibold))
                    .foregroundColor(Turf.booking)
                    .transition(.opacity)
            }
            HStack(spacing: 12) {
                if draft.step != .event {
                    Button {
                        move(-1)
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 17, weight: .heavy))
                            .frame(width: 22)
                    }
                    .buttonStyle(ChalkLineButton())
                    .frame(width: 70)
                }
                Button(draft.step == .draw ? "Blow the whistle" : "Next") {
                    guard issue == nil else {
                        Buzz.deny()
                        return
                    }
                    if draft.step == .draw {
                        Buzz.thud()
                        club.open(draft.build())
                    } else {
                        move(1)
                    }
                }
                .buttonStyle(FloodlitButton(fill: issue == nil ? Turf.floodlight : Turf.stripe, text: issue == nil ? Turf.ink : Turf.haze))
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            LinearGradient(colors: [Turf.night.opacity(0), Turf.night], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
        .animation(.easeOut(duration: 0.2), value: issue)
    }

    private func move(_ delta: Int) {
        guard let next = Draft.Step(rawValue: draft.step.rawValue + delta) else { return }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        if next == .draw && draft.drawn.count != draft.teams.count { draft.drawn.removeAll() }
        forward = delta > 0
        Buzz.tick()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { draft.step = next }
    }
}

private struct TouchLine: View {
    let step: Draft.Step

    var body: some View {
        let all = Draft.Step.allCases
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                let gap = geo.size.width / CGFloat(all.count - 1)
                ZStack(alignment: .leading) {
                    Capsule().fill(Turf.chalk.opacity(0.14)).frame(height: 3)
                    Capsule().fill(Turf.chalk).frame(width: gap * CGFloat(step.rawValue), height: 3)
                    ForEach(all, id: \.self) { s in
                        Circle()
                            .fill(s.rawValue <= step.rawValue ? Turf.chalk : Turf.stripe)
                            .frame(width: 9, height: 9)
                            .offset(x: gap * CGFloat(s.rawValue) - 4.5)
                    }
                    Text("⚽️")
                        .font(.system(size: 20))
                        .rotationEffect(.degrees(Double(step.rawValue) * 144))
                        .offset(x: gap * CGFloat(step.rawValue) - 11)
                }
                .frame(height: 24)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: step)
            }
            .frame(height: 24)
            HStack {
                Text("STEP \(step.rawValue + 1) OF \(all.count)")
                    .font(.tally(11, .bold))
                    .foregroundColor(Turf.haze)
                Spacer()
                Text(step.title.uppercased())
                    .font(.copy(11, .heavy))
                    .tracking(1.6)
                    .foregroundColor(Turf.floodlight)
            }
        }
    }
}
