import SwiftUI

struct BracketBoard: View {
    let t: Tournament
    @EnvironmentObject private var dugout: Dugout

    private let box = CGSize(width: 168, height: 64)
    private let gap: CGFloat = 14
    private let lane: CGFloat = 34

    var body: some View {
        let ko = t.fixtures.filter { $0.stage.kind == .knockout }
        let top = ko.map(\.stage.round).max() ?? 0
        let rounds = Array((1...max(top, 1)).reversed())
        let height = CGFloat(1 << max(top - 1, 0)) * (box.height + gap)

        VStack(alignment: .leading, spacing: 18) {
            if ko.isEmpty {
                EmptyPitch(art: .trophy, title: "No bracket", message: "This format finishes on the table.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: lane) {
                        ForEach(rounds, id: \.self) { r in
                            column(t, round: r, top: top, height: height)
                        }
                        if let champ = t.podium.champion {
                            VStack(spacing: 6) {
                                Art(art: .trophy, height: 90)
                                Text(champ.name)
                                    .font(.banner(16))
                                    .foregroundColor(Turf.floodlight)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 130)
                            .frame(height: height + 30, alignment: .center)
                        }
                    }
                    .padding(.horizontal, 18)
                }

                if let bronze = t.fixtures.first(where: { $0.stage.kind == .bronze }) {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Third place")
                        Button {
                            dugout.path(.table).wrappedValue.append(.fixture(bronze.id))
                        } label: {
                            FixtureTicket(t: t, f: bronze)
                        }
                        .buttonStyle(Squash())
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
    }

    private func column(_ t: Tournament, round r: Int, top: Int, height: CGFloat) -> some View {
        let slots = 1 << (r - 1)
        let step = height / CGFloat(slots)
        return VStack(alignment: .leading, spacing: 8) {
            Text(Stage(kind: .knockout, round: r).roundName.uppercased())
                .font(.copy(11, .heavy))
                .tracking(1.4)
                .foregroundColor(Turf.haze)
                .frame(height: 22)
            ZStack(alignment: .topLeading) {
                if r < top {
                    Wires(slots: slots * 2, box: box, lane: lane)
                        .stroke(Turf.chalk.opacity(0.28), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                        .frame(width: lane, height: height)
                        .offset(x: -lane)
                }
                ForEach(0..<slots, id: \.self) { i in
                    let f = t.fixtures.first { $0.stage.kind == .knockout && $0.stage.round == r && $0.stage.index == i }
                    Group {
                        if let f {
                            Button {
                                dugout.path(.table).wrappedValue.append(.fixture(f.id))
                            } label: {
                                matchBox(t, f)
                            }
                            .buttonStyle(Squash())
                        } else {
                            byeBox
                        }
                    }
                    .frame(width: box.width, height: box.height)
                    .offset(y: step * CGFloat(i) + (step - box.height) / 2)
                }
            }
            .frame(width: box.width, height: height, alignment: .topLeading)
        }
    }

    private func matchBox(_ t: Tournament, _ f: Fixture) -> some View {
        VStack(spacing: 0) {
            ForEach(Side.allCases, id: \.self) { s in
                let team = t.team(at: f.seat(s))
                let won = f.winningSide == s
                HStack(spacing: 6) {
                    Kit(index: team?.kit ?? 10, size: 10)
                        .opacity(team == nil ? 0.3 : 1)
                    Text(team?.name ?? t.label(f.seat(s)))
                        .font(.copy(12, won ? .heavy : .semibold))
                        .italic(team == nil)
                        .foregroundColor(team == nil ? Turf.haze : (won || f.winningSide == nil ? Turf.chalk : Turf.chalk.opacity(0.55)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 2)
                    if f.status != .scheduled {
                        Text("\(f.goals(s))\(f.shootout.map { "(\(s == .home ? $0.home : $0.away))" } ?? "")")
                            .font(.tally(12, .bold))
                            .foregroundColor(won ? Turf.floodlight : Turf.chalk)
                    }
                }
                .padding(.horizontal, 10)
                .frame(maxHeight: .infinity)
                if s == .home {
                    Rectangle().fill(Turf.line).frame(height: 1)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(f.status == .live ? Turf.stripe : Turf.pitch))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(f.status == .live ? Turf.floodlight : Turf.chalk.opacity(0.08), lineWidth: 1)
        )
    }

    private var byeBox: some View {
        Text("bye")
            .font(.copy(12, .heavy))
            .foregroundColor(Turf.haze.opacity(0.6))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Turf.chalk.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
    }
}

private struct Wires: Shape {
    let slots: Int
    let box: CGSize
    let lane: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step = rect.height / CGFloat(slots)
        for k in 0..<(slots / 2) {
            let a = step * (CGFloat(2 * k) + 0.5)
            let b = step * (CGFloat(2 * k + 1) + 0.5)
            let mid = (a + b) / 2
            let x0 = rect.minX
            let x1 = rect.midX
            p.move(to: CGPoint(x: x0, y: a))
            p.addLine(to: CGPoint(x: x1, y: a))
            p.addLine(to: CGPoint(x: x1, y: b))
            p.addLine(to: CGPoint(x: x0, y: b))
            p.move(to: CGPoint(x: x1, y: mid))
            p.addLine(to: CGPoint(x: rect.maxX, y: mid))
        }
        return p
    }
}
