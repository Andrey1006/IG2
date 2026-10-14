import SwiftUI

struct FixtureTicket: View {
    let t: Tournament
    let f: Fixture
    var showStage = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(Clockface.time.string(from: f.kickoff))
                    .font(.scoreboard(19))
                    .foregroundColor(f.status == .finished ? Turf.haze : Turf.chalk)
                Text("PITCH \(Stage.pitchName(f.pitch))")
                    .font(.copy(9, .heavy))
                    .tracking(0.8)
                    .foregroundColor(Turf.haze)
            }
            .frame(width: 64)

            Perforation()
                .stroke(Turf.chalk.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 6) {
                if showStage || f.stage.isKnockout {
                    Text(f.stage.title.uppercased())
                        .font(.copy(9, .heavy))
                        .tracking(1.2)
                        .foregroundColor(f.stage.isKnockout ? Turf.floodlight : Turf.haze)
                }
                line(.home)
                line(.away)
            }
            .padding(.leading, 14)
            .padding(.trailing, 12)
            .padding(.vertical, 12)

            StatusMark(f: f)
                .padding(.trailing, 12)
        }
        .background(Ticket(stub: 64).fill(f.status == .live ? Turf.stripe : Turf.pitch))
        .overlay(
            Ticket(stub: 64)
                .stroke(f.status == .live ? Turf.floodlight.opacity(0.7) : Turf.chalk.opacity(0.06), lineWidth: f.status == .live ? 1.5 : 1)
        )
    }

    private func line(_ side: Side) -> some View {
        let team = t.team(at: f.seat(side))
        let won = f.winningSide == side
        return HStack(spacing: 8) {
            if let team {
                Kit(index: team.kit, size: 13)
            } else {
                Circle().stroke(Turf.haze.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2, 2])).frame(width: 13, height: 13)
            }
            Text(t.label(f.seat(side)))
                .font(.copy(15, won ? .heavy : .semibold))
                .italic(team == nil)
                .foregroundColor(team == nil ? Turf.haze : (f.status == .finished && !won && f.winningSide != nil ? Turf.chalk.opacity(0.6) : Turf.chalk))
                .lineLimit(1)
            Spacer(minLength: 4)
            if f.status != .scheduled {
                if let s = f.shootout {
                    Text("(\(side == .home ? s.home : s.away))")
                        .font(.tally(11))
                        .foregroundColor(Turf.haze)
                }
                Text("\(f.goals(side))")
                    .font(.scoreboard(21))
                    .foregroundColor(won ? Turf.floodlight : Turf.chalk)
                    .contentTransition(.numericText())
            }
        }
    }
}

struct StatusMark: View {
    let f: Fixture

    var body: some View {
        switch f.status {
        case .live:
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                VStack(spacing: 3) {
                    LiveDot()
                    Text("\(f.clock.minute(at: ctx.date))′")
                        .font(.tally(12, .bold))
                        .foregroundColor(Turf.floodlight)
                }
            }
            .frame(width: 34)
        case .finished:
            Text("FT")
                .font(.copy(11, .heavy))
                .foregroundColor(Turf.haze)
                .frame(width: 34)
        case .scheduled:
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Turf.haze.opacity(0.6))
                .frame(width: 34)
        }
    }
}

struct LiveDot: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(Turf.dismissal)
            .frame(width: 8, height: 8)
            .background(
                Circle()
                    .fill(Turf.dismissal.opacity(0.4))
                    .scaleEffect(pulse ? 2.4 : 1)
                    .opacity(pulse ? 0 : 1)
            )
            .onAppear {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { pulse = true }
            }
    }
}
