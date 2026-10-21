import SwiftUI

struct SquadStep: View {
    @ObservedObject var draft: Draft
    @State private var rosterFor: UUID?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Masthead(kicker: "\(draft.teams.count) of 32", title: "Who's playing?")

                HStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.35)) {
                            draft.teams = Rehearsal.teams
                            draft.settleFormat()
                        }
                        Buzz.tick()
                    } label: { Chip(text: "↺ Sample squad") }
                    Button {
                        withAnimation(.spring(response: 0.35)) {
                            draft.teams = []
                            draft.settleFormat()
                        }
                        Buzz.tick()
                    } label: { Chip(text: "Clear list") }
                    Spacer()
                }
                .buttonStyle(Squash())

                Text("⭐️ Seeded teams are drawn first, so they never meet in the group stage.")
                    .font(.copy(13))
                    .foregroundColor(Turf.haze)

                VStack(spacing: 10) {
                    ForEach($draft.teams) { $team in
                        TeamLine(team: $team, onRoster: { rosterFor = team.id }) {
                            withAnimation(.spring(response: 0.3)) {
                                draft.teams.removeAll { $0.id == team.id }
                                draft.settleFormat()
                            }
                            Buzz.tick()
                        }
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .scale(scale: 0.9).combined(with: .opacity)))
                    }
                }

                if draft.teams.count < 32 {
                    Button {
                        withAnimation(.spring(response: 0.35)) {
                            draft.teams.append(Team(name: "", kit: draft.teams.count))
                            draft.settleFormat()
                        }
                        Buzz.tick()
                    } label: {
                        Label("Add team", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ChalkLineButton(tint: Turf.floodlight))
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(item: Binding(get: { rosterFor.map(SheetID.init) }, set: { rosterFor = $0?.id })) { sheet in
            if let i = draft.teams.firstIndex(where: { $0.id == sheet.id }) {
                RosterSheet(team: $draft.teams[i])
            }
        }
    }
}

struct SheetID: Identifiable {
    let id: UUID
}

private struct TeamLine: View {
    @Binding var team: Team
    let onRoster: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                team.kit += 1
                Buzz.tick()
            } label: {
                Kit(index: team.kit, size: 30, crest: team.crest)
            }
            .buttonStyle(Squash())

            ChalkField(placeholder: "Team name", text: $team.name, size: 16)

            Button {
                team.seeded.toggle()
                Buzz.tick()
            } label: {
                Text(team.seeded ? "⭐️" : "☆")
                    .font(.system(size: team.seeded ? 20 : 24, weight: .bold))
                    .foregroundColor(Turf.haze)
                    .frame(width: 34, height: 40)
            }
            .buttonStyle(Squash())

            Button(action: onRoster) {
                VStack(spacing: 0) {
                    Text("👕").font(.system(size: 15))
                    Text("\(team.players.count)")
                        .font(.tally(11, .bold))
                        .foregroundColor(Turf.chalk)
                }
                .frame(width: 38, height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Turf.night.opacity(0.6)))
            }
            .buttonStyle(Squash())

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(Turf.haze)
                    .frame(width: 26, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Turf.pitch))
    }
}

struct RosterSheet: View {
    @Binding var team: Team
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var number = ""

    var body: some View {
        ZStack {
            Turf.night.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    CrestPicker(crest: $team.crest, kit: team.kit, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(team.name.isEmpty ? "New team" : team.name)
                            .font(.banner(24))
                            .foregroundColor(Turf.chalk)
                        Text(team.crest == nil ? "Tap the badge to add a crest" : "Tap the badge to change the crest")
                            .font(.copy(12))
                            .foregroundColor(Turf.haze)
                    }
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(ChalkLineButton(compact: true))
                }

                Text("Optional — players can also be added from the touchline when they score or get booked.")
                    .font(.copy(13))
                    .foregroundColor(Turf.haze)

                HStack(spacing: 8) {
                    ChalkField(placeholder: "#", text: $number, keyboard: .numberPad)
                        .frame(width: 64)
                    ChalkField(placeholder: "Player name", text: $name)
                    Button {
                        add()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(Turf.ink)
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(Turf.floodlight))
                    }
                    .buttonStyle(Squash())
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(team.players) { p in
                            HStack {
                                Text(p.number.map { "\($0)" } ?? "–")
                                    .font(.scoreboard(20))
                                    .foregroundColor(Turf.floodlight)
                                    .frame(width: 36)
                                Text(p.name)
                                    .font(.copy(16, .semibold))
                                    .foregroundColor(Turf.chalk)
                                Spacer()
                                Button {
                                    withAnimation { team.players.removeAll { $0.id == p.id } }
                                    Buzz.tick()
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundColor(Turf.haze)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Turf.pitch))
                        }
                        if team.players.isEmpty {
                            Text("No players yet")
                                .font(.copy(14))
                                .foregroundColor(Turf.haze)
                                .padding(.top, 30)
                        }
                    }
                }
            }
            .padding(22)
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    private func add() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            Buzz.deny()
            return
        }
        withAnimation(.spring(response: 0.3)) {
            team.players.append(Player(name: trimmed, number: Int(number)))
        }
        name = ""
        number = ""
        Buzz.tick()
    }
}
