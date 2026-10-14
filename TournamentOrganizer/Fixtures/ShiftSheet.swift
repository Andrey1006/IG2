import SwiftUI

struct ShiftSheet: View {
    let t: Tournament
    @EnvironmentObject private var club: Clubhouse
    @Environment(\.dismiss) private var dismiss
    @State private var pitch = 0
    @State private var minutes = 0
    @State private var anchor: Int?

    private let notch: CGFloat = 14

    private var pending: [Fixture] {
        t.fixtures.filter { $0.pitch == pitch && $0.status == .scheduled }.sorted { $0.kickoff < $1.kickoff }
    }

    var body: some View {
        ZStack {
            Turf.night.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Masthead(kicker: "Running late?", title: "Shift a pitch")
                    Button("Close") { dismiss() }
                        .buttonStyle(ChalkLineButton(compact: true))
                }

                if t.pitches > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<t.pitches, id: \.self) { p in
                            Button {
                                pitch = p
                                Buzz.tick()
                            } label: { Chip(text: "Pitch \(Stage.pitchName(p))", on: pitch == p) }
                            .buttonStyle(Squash())
                        }
                    }
                }

                VStack(spacing: 10) {
                    Text(minutes == 0 ? "On time" : "\(minutes > 0 ? "+" : "−")\(abs(minutes)) min")
                        .font(.scoreboard(56))
                        .foregroundColor(minutes == 0 ? Turf.chalk : (minutes > 0 ? Turf.booking : Turf.floodlight))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.25), value: minutes)
                    ruler
                    Text("Drag the chalk line. Every 5 minutes clicks.")
                        .font(.copy(12))
                        .foregroundColor(Turf.haze)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .flagCard()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(pending) { f in
                            HStack {
                                Text(Clockface.time.string(from: f.kickoff))
                                    .font(.tally(14))
                                    .foregroundColor(Turf.haze)
                                    .strikethrough(minutes != 0)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Turf.haze)
                                Text(Clockface.time.string(from: f.kickoff.addingTimeInterval(TimeInterval(minutes * 60))))
                                    .font(.tally(14, .bold))
                                    .foregroundColor(Turf.chalk)
                                Spacer()
                                Text("\(t.team(at: f.home)?.code ?? "TBD") v \(t.team(at: f.away)?.code ?? "TBD")")
                                    .font(.copy(13, .bold))
                                    .foregroundColor(Turf.chalk)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 40)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Turf.pitch))
                        }
                        if pending.isEmpty {
                            Text("No upcoming fixtures on this pitch.")
                                .font(.copy(14))
                                .foregroundColor(Turf.haze)
                                .padding(.top, 20)
                        }
                    }
                }

                Button("Move \(pending.count) fixtures") {
                    guard minutes != 0, !pending.isEmpty else {
                        Buzz.deny()
                        return
                    }
                    club.shiftPitch(pitch, minutes: minutes)
                    Buzz.success()
                    dismiss()
                }
                .buttonStyle(FloodlitButton())
            }
            .padding(22)
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }

    private var ruler: some View {
        GeometryReader { geo in
            let mid = geo.size.width / 2
            ZStack {
                ForEach(-24...24, id: \.self) { i in
                    let x = mid + CGFloat(i) * notch + CGFloat(minutes / 5) * -notch
                    Capsule()
                        .fill(i * 5 == minutes ? Turf.floodlight : Turf.chalk.opacity(i % 3 == 0 ? 0.55 : 0.25))
                        .frame(width: 3, height: i % 3 == 0 ? 30 : 16)
                        .position(x: x, y: 24)
                }
                Rectangle()
                    .fill(Turf.floodlight)
                    .frame(width: 2, height: 46)
                    .position(x: mid, y: 24)
            }
        }
        .frame(height: 48)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { g in
                    if anchor == nil { anchor = minutes }
                    let next = min(max((anchor ?? 0) - Int(g.translation.width / notch) * 5, -60), 120)
                    if next != minutes {
                        minutes = next
                        if next % 15 == 0 { Buzz.threshold() } else { Buzz.tick() }
                    }
                }
                .onEnded { _ in anchor = nil }
        )
        .animation(.interactiveSpring(), value: minutes)
    }
}
