import SwiftUI

struct DeskScreen: View {
    @EnvironmentObject private var club: Clubhouse
    @EnvironmentObject private var dugout: Dugout
    @State private var privacy = false
    @State private var confirmWipe = false
    @State private var confirmPackUp = false
    @State private var confirmClose = false

    var body: some View {
        if let t = club.tournament {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Masthead(kicker: "Organiser's desk", title: "Desk")
                    hero(t)

                    Button("📸  Share results poster") { dugout.posterOpen = true }
                        .buttonStyle(FloodlitButton())

                    VStack(spacing: 0) {
                        row("📏", "House rules", "\(t.rules.win)-\(t.rules.draw) points · 🟨×\(t.rules.yellowLimit) ban") {
                            dugout.path(.desk).wrappedValue.append(.rules)
                        }
                        Divider().overlay(Turf.line).padding(.leading, 56)
                        row("🏅", "Hall of Fame", club.book.honours.isEmpty ? "No past tournaments" : "\(club.book.honours.count) archived") {
                            dugout.path(.desk).wrappedValue.append(.hall)
                        }
                    }
                    .flagCard()

                    Button(t.isOver ? "🏁  Close & archive tournament" : "Close tournament early") { confirmClose = true }
                        .buttonStyle(ChalkLineButton(tint: t.isOver ? Turf.floodlight : Turf.haze))
                        .frame(maxWidth: .infinity)

                    SectionLabel(text: "Settings")
                    VStack(spacing: 0) {
                        ChalkSwitch(
                            title: "Haptics",
                            detail: "Clicks, thumps and buzzes on the touchline.",
                            isOn: Binding(get: { club.book.haptics }, set: { club.setHaptics($0) })
                        )
                        .padding(16)
                        Divider().overlay(Turf.line)
                        row("🔒", "Privacy Policy", "Opens in a sheet") { privacy = true }
                    }
                    .flagCard(notch: 14)

                    VStack(spacing: 0) {
                        row("🧽", "Clear the scoresheet", "Keeps teams and schedule, wipes every result", tint: Turf.booking) { confirmWipe = true }
                        Divider().overlay(Turf.line).padding(.leading, 56)
                        row("🧳", "Pack up the pitch", "Deletes everything incl. Hall of Fame", tint: Turf.dismissal) { confirmPackUp = true }
                    }
                    .flagCard()

                    Text("Match Bracket keeps everything on this phone. No accounts, no sync, works without signal.")
                        .font(.copy(12))
                        .foregroundColor(Turf.haze)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
            .turfScreen()
            .sheet(isPresented: $dugout.posterOpen) { PosterSheet(t: t) }
            .sheet(isPresented: $privacy) { PrivacySheet() }
            .alert("Clear the scoresheet?", isPresented: $confirmWipe) {
                Button("Clear results", role: .destructive) {
                    club.clearScoresheet()
                    Buzz.thud()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Every goal, card, shootout and stopwatch goes. Teams, the draw and the schedule stay.")
            }
            .alert("Pack up the pitch?", isPresented: $confirmPackUp) {
                Button("Delete everything", role: .destructive) {
                    club.packUp()
                    Buzz.thud()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The current tournament, all teams and the Hall of Fame will be deleted from this phone. This can't be undone.")
            }
            .alert(t.isOver ? "Archive \(t.name)?" : "Close before the end?", isPresented: $confirmClose) {
                Button("Close tournament", role: .destructive) {
                    club.closeTournament()
                    Buzz.success()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(t.isOver
                     ? "The champion and top scorer go to the Hall of Fame and you can set up the next one."
                     : "\(t.fixtures.count - t.played) fixtures are unplayed. The archive will record it without a full result.")
            }
        }
    }

    private func hero(_ t: Tournament) -> some View {
        let progress = t.fixtures.isEmpty ? 0 : Double(t.played) / Double(t.fixtures.count)
        return VStack(alignment: .leading, spacing: 0) {
            ArtBand(art: .floodlights, height: 120)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t.name)
                            .font(.banner(22))
                            .foregroundColor(Turf.chalk)
                        Text("\(t.format.title) · \(t.teams.count) teams · \(t.pitches) pitch\(t.pitches == 1 ? "" : "es")")
                            .font(.copy(13, .semibold))
                            .foregroundColor(Turf.haze)
                    }
                    Spacer()
                    if let champ = t.podium.champion {
                        VStack(spacing: 2) {
                            Text("🏆").font(.system(size: 24))
                            Text(champ.code)
                                .font(.copy(11, .heavy))
                                .foregroundColor(Turf.floodlight)
                        }
                    }
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Turf.night)
                        Capsule()
                            .fill(Turf.floodlight)
                            .frame(width: max(8, geo.size.width * progress))
                        Text("⚽️")
                            .font(.system(size: 14))
                            .offset(x: max(0, geo.size.width * progress - 14))
                    }
                }
                .frame(height: 10)
                HStack {
                    Text("\(t.played) of \(t.fixtures.count) played")
                    Spacer()
                    Text("Final whistle ≈ \(t.finishTime.map { Clockface.time.string(from: $0) } ?? "—")")
                }
                .font(.tally(12, .bold))
                .foregroundColor(Turf.haze)
            }
            .padding(16)
        }
        .clipShape(CornerFlag())
        .flagCard()
    }

    private func row(_ emoji: String, _ title: String, _ detail: String, tint: Color = Turf.chalk, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(emoji)
                    .font(.system(size: 20))
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.copy(16, .bold))
                        .foregroundColor(tint)
                    Text(detail)
                        .font(.copy(12))
                        .foregroundColor(Turf.haze)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Turf.haze)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(Squash())
    }
}
