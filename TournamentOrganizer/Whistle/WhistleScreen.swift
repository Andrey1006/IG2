import SwiftUI

struct WhistleScreen: View {
    @EnvironmentObject private var club: Clubhouse
    @EnvironmentObject private var dugout: Dugout
    @State private var callingUp = false
    @State private var lifted: Team?
    @State private var starFor: UUID?

    var body: some View {
        ZStack {
            Mown(bands: 7).ignoresSafeArea()
            if let t = club.tournament {
                let live = t.fixtures.filter { $0.status == .live }.sorted { $0.kickoff < $1.kickoff }
                if let f = live.first(where: { $0.id == dugout.focus }) ?? live.first {
                    VStack(spacing: 10) {
                        switcher(t, live, focus: f.id)
                        RefereeBoard(t: t, f: f) { done in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { starFor = done.id }
                            guard let now = club.tournament else { return }
                            let decided = (done.stage.kind == .knockout && done.stage.round == 1) || (now.format == .league && now.isOver)
                            guard decided, let champ = now.podium.champion else { return }
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { lifted = champ }
                        }
                        .id(f.id)
                    }
                    .padding(.top, 6)
                    .frame(maxWidth: Turf.column)
                } else {
                    restingState(t)
                        .frame(maxWidth: Turf.column)
                }
            }

            if let lifted {
                Celebration(team: lifted) {
                    withAnimation(.easeOut(duration: 0.3)) { self.lifted = nil }
                } onShare: {
                    self.lifted = nil
                    dugout.tab = .desk
                    dugout.posterOpen = true
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .zIndex(3)
            }
        }
        .sheet(item: Binding(get: { starFor.map(SheetID.init) }, set: { starFor = $0?.id })) { sheet in
            if let t = club.tournament, let f = t.fixture(sheet.id) {
                StarSheet(t: t, f: f) { club.crown($0, in: f.id) }
            }
        }
        .sheet(isPresented: $callingUp) {
            if let t = club.tournament {
                ZStack {
                    Turf.night.ignoresSafeArea()
                    ScrollView(showsIndicators: false) {
                        NextUpList(t: t) { callingUp = false }
                            .padding(20)
                    }
                }
                .presentationDetents([.medium, .large])
                .preferredColorScheme(.dark)
            }
        }
    }

    private func switcher(_ t: Tournament, _ live: [Fixture], focus: UUID) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(live) { f in
                    Button {
                        dugout.focus = f.id
                        Buzz.tick()
                    } label: {
                        HStack(spacing: 6) {
                            Text(Stage.pitchName(f.pitch))
                                .font(.copy(11, .heavy))
                                .foregroundColor(f.id == focus ? Turf.chalk : Turf.ink)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(f.id == focus ? Turf.ink : Turf.haze))
                            Text("\(t.team(at: f.home)?.code ?? "") \(f.goals(.home))–\(f.goals(.away)) \(t.team(at: f.away)?.code ?? "")")
                                .font(.copy(13, .heavy))
                                .foregroundColor(f.id == focus ? Turf.ink : Turf.chalk)
                        }
                        .padding(.leading, 6)
                        .padding(.trailing, 12)
                        .frame(height: 34)
                        .background(Capsule().fill(f.id == focus ? Turf.floodlight : Turf.pitch))
                    }
                    .buttonStyle(Squash())
                }
                if t.fixtures.contains(where: { $0.status == .scheduled && t.isReady($0) }) {
                    Button {
                        callingUp = true
                    } label: {
                        Label("Kick off", systemImage: "plus")
                            .font(.copy(13, .heavy))
                            .foregroundColor(Turf.chalk)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .overlay(Capsule().stroke(Turf.chalk.opacity(0.4), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])))
                    }
                    .buttonStyle(Squash())
                }
            }
            .padding(.horizontal, 18)
        }
    }

    @ViewBuilder
    private func restingState(_ t: Tournament) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Masthead(kicker: "The Whistle", title: t.isOver ? "That's full time" : "Ready when you are")
                if t.isOver {
                    EmptyPitch(
                        art: .trophy,
                        title: t.podium.champion.map { "\($0.name) win it" } ?? "All matches played",
                        message: "Every fixture has its final whistle. Send the results to the group chat.",
                        action: ("Make the poster", {
                            dugout.tab = .desk
                            dugout.posterOpen = true
                        })
                    )
                } else if t.fixtures.contains(where: { $0.status == .scheduled && t.isReady($0) }) {
                    NextUpList(t: t, onKickoff: nil)
                } else {
                    EmptyPitch(
                        art: .benchWhistle,
                        title: "Waiting on results",
                        message: "The next fixtures depend on matches that haven't been decided yet. Check the shootouts in Fixtures."
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
    }
}

struct NextUpList: View {
    let t: Tournament
    var onKickoff: (() -> Void)?
    @EnvironmentObject private var club: Clubhouse
    @EnvironmentObject private var dugout: Dugout

    var body: some View {
        let ready = t.fixtures
            .filter { $0.status == .scheduled && t.isReady($0) }
            .sorted { $0.kickoff == $1.kickoff ? $0.pitch < $1.pitch : $0.kickoff < $1.kickoff }
            .prefix(6)
        let busy = Set(t.fixtures.filter { $0.status == .live }.map(\.pitch))

        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Next up", trailing: "\(ready.count)")
            ForEach(Array(ready)) { f in
                VStack(spacing: 8) {
                    FixtureTicket(t: t, f: f, showStage: true)
                    Button(busy.contains(f.pitch) ? "Pitch \(Stage.pitchName(f.pitch)) is busy — kick off anyway" : "Kick off ⚽️") {
                        club.kickOff(f.id)
                        Buzz.thud()
                        dugout.focus = f.id
                        onKickoff?()
                    }
                    .buttonStyle(ChalkLineButton(tint: busy.contains(f.pitch) ? Turf.haze : Turf.floodlight, compact: true))
                }
            }
        }
    }
}

private struct Celebration: View {
    let team: Team
    let onClose: () -> Void
    let onShare: () -> Void
    @State private var rise = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 16) {
                Art(art: .trophy, height: 170)
                    .scaleEffect(rise ? 1 : 0.6)
                    .rotationEffect(.degrees(rise ? 0 : -12))
                Text("CHAMPIONS")
                    .font(.copy(13, .heavy))
                    .tracking(3)
                    .foregroundColor(Turf.inkGold)
                Text(team.name)
                    .font(.banner(34))
                    .foregroundColor(Turf.ink)
                    .multilineTextAlignment(.center)
                Text("🎉 🏆 🎉")
                    .font(.system(size: 28))
                Button("Share the poster", action: onShare)
                    .buttonStyle(FloodlitButton(fill: Turf.ink, text: Turf.floodlight))
                Button("Later", action: onClose)
                    .buttonStyle(ChalkLineButton(tint: Turf.ink, compact: true))
            }
            .padding(26)
            .flagCard(Turf.paper, radius: 28, notch: 40)
            .padding(28)
        }
        .onAppear {
            Buzz.success()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) { rise = true }
        }
    }
}
