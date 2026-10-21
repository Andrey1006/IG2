import SwiftUI
import UIKit

enum PosterKind: String, CaseIterable, Identifiable {
    case honours, standings, bracket, results

    var id: String { rawValue }

    var label: String {
        switch self {
        case .honours: return "🏆 Summary"
        case .standings: return "📋 Table"
        case .bracket: return "⚔️ Bracket"
        case .results: return "⚽️ Results"
        }
    }
}

struct PosterSheet: View {
    let t: Tournament
    @Environment(\.dismiss) private var dismiss
    @State private var kind = PosterKind.honours
    @State private var rendered: UIImage?

    private var kinds: [PosterKind] {
        PosterKind.allCases.filter { k in
            switch k {
            case .standings: return t.format != .knockout
            case .bracket: return t.format != .league
            default: return true
            }
        }
    }

    var body: some View {
        ZStack {
            Turf.night.ignoresSafeArea()
            VStack(spacing: 14) {
                HStack {
                    Text("Results poster")
                        .font(.banner(24))
                        .foregroundColor(Turf.chalk)
                    Spacer()
                    Button("Close") { dismiss() }
                        .buttonStyle(ChalkLineButton(compact: true))
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(kinds) { k in
                            Button {
                                kind = k
                                Buzz.tick()
                            } label: { Chip(text: k.label, on: kind == k) }
                            .buttonStyle(Squash())
                        }
                    }
                }
                ScrollView(showsIndicators: false) {
                    PosterView(t: t, kind: kind)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
                        .padding(.vertical, 6)
                }
                if let rendered {
                    ShareLink(
                        item: Image(uiImage: rendered),
                        preview: SharePreview("\(t.name) — \(kind.label)", image: Image(uiImage: rendered))
                    ) {
                        Text("Send to the chat")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FloodlitButton())
                    .simultaneousGesture(TapGesture().onEnded { Buzz.success() })
                } else {
                    ProgressView().tint(Turf.floodlight).frame(height: 54)
                }
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: render)
        .onChange(of: kind) { _ in render() }
    }

    private func render() {
        let r = ImageRenderer(content: PosterView(t: t, kind: kind))
        r.scale = 3
        rendered = r.uiImage
    }
}

struct PosterView: View {
    let t: Tournament
    let kind: PosterKind

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                ArtBand(art: .posterBand, height: 130, emblem: false)
                LinearGradient(colors: [.clear, Turf.ink.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Clockface.day.string(from: t.start).uppercased() + " · " + t.format.title.uppercased())
                        .font(.copy(10, .heavy))
                        .tracking(1.6)
                        .foregroundColor(Turf.floodlight)
                    Text(t.name)
                        .font(.banner(26))
                        .foregroundColor(Turf.chalk)
                }
                .padding(18)
            }
            .frame(height: 130)

            VStack(alignment: .leading, spacing: 14) {
                switch kind {
                case .honours: honours
                case .standings: standings
                case .bracket: bracket
                case .results: results
                }
            }
            .padding(18)

            HStack {
                Text("Match Bracket ⚽️")
                    .font(.copy(11, .heavy))
                Spacer()
                Text("\(t.played)/\(t.fixtures.count) played · \(t.totalGoals) goals")
                    .font(.tally(10))
            }
            .foregroundColor(Turf.inkHaze)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Turf.paperShade)
        }
        .frame(width: 360)
        .background(Turf.paper)
    }

    @ViewBuilder
    private var honours: some View {
        let podium = t.podium
        HStack(spacing: 14) {
            Art(art: .trophy, height: 76)
            VStack(alignment: .leading, spacing: 3) {
                Text(podium.champion == nil ? "STILL IN PLAY" : "CHAMPIONS")
                    .font(.copy(10, .heavy))
                    .tracking(2)
                    .foregroundColor(Turf.inkGold)
                Text(podium.champion?.name ?? leaderLine)
                    .font(.banner(24))
                    .foregroundColor(Turf.ink)
                if let r = podium.runnerUp {
                    Text("Runner-up · \(r.name)")
                        .font(.copy(13, .semibold))
                        .foregroundColor(Turf.inkHaze)
                }
            }
        }
        inkLabel("Top scorers")
        let top = Array(t.scorers.prefix(5))
        if top.isEmpty {
            Text("No goals yet").font(.copy(13)).foregroundColor(Turf.inkHaze)
        }
        ForEach(Array(top.enumerated()), id: \.element.id) { i, s in
            HStack(spacing: 8) {
                Text(i == 0 ? "👟" : "\(i + 1)")
                    .font(.tally(12, .bold))
                    .frame(width: 22)
                Kit(index: s.team.kit, size: 10, crest: s.team.crest)
                Text(s.player.name).font(.copy(14, .bold))
                Text(s.team.code).font(.copy(10, .heavy)).foregroundColor(Turf.inkHaze)
                Spacer()
                Text("\(s.goals)").font(.scoreboard(20))
            }
            .foregroundColor(Turf.ink)
        }
        let carded = Set(t.cardTable.map(\.team.id))
        let clean = t.teams.filter { !carded.contains($0.id) }
        inkLabel("Fair play")
        Text(clean.isEmpty
             ? "🤝 \(t.cardTable.first?.team.name ?? "") — \(t.cardTable.first?.points ?? 0) card points"
             : "🤝 No cards: " + clean.map(\.code).joined(separator: ", "))
            .font(.copy(13, .semibold))
            .foregroundColor(Turf.ink)
    }

    private var leaderLine: String {
        if t.format == .league, let first = t.table(group: nil).first { return "\(first.team.name) lead" }
        let left = t.fixtures.count - t.played
        return "\(left) match\(left == 1 ? "" : "es") to go"
    }

    @ViewBuilder
    private var standings: some View {
        let sets: [(String, Int?, Int)] = t.format == .league
            ? [("League", nil, 1)]
            : (0..<t.groups.count).map { ("Group \(Stage.letter($0))", $0, t.advance) }
        ForEach(sets, id: \.0) { title, g, zone in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    inkLabel(title)
                    Spacer()
                    Text("P   GD   PTS")
                        .font(.tally(10, .bold))
                        .foregroundColor(Turf.inkHaze)
                }
                ForEach(Array(t.table(group: g).enumerated()), id: \.element.id) { i, row in
                    HStack(spacing: 8) {
                        Text("\(i + 1)")
                            .font(.tally(12, .bold))
                            .foregroundColor(i < zone ? Turf.inkGold : Turf.inkHaze)
                            .frame(width: 16)
                        Kit(index: row.team.kit, size: 10, crest: row.team.crest)
                        Text(row.team.name)
                            .font(.copy(13, i < zone ? .heavy : .semibold))
                            .lineLimit(1)
                        Spacer()
                        Text("\(row.played)").font(.tally(11)).frame(width: 18)
                        Text(row.diff > 0 ? "+\(row.diff)" : "\(row.diff)").font(.tally(11)).frame(width: 28)
                        Text("\(row.points)").font(.scoreboard(17)).frame(width: 28, alignment: .trailing)
                    }
                    .foregroundColor(Turf.ink)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private var bracket: some View {
        let ko = t.fixtures.filter(\.stage.isKnockout)
        let rounds = Set(ko.filter { $0.stage.kind == .knockout }.map(\.stage.round)).sorted(by: >)
        ForEach(rounds, id: \.self) { r in
            inkLabel(Stage(kind: .knockout, round: r).roundName)
            ForEach(ko.filter { $0.stage.kind == .knockout && $0.stage.round == r }.sorted { $0.stage.index < $1.stage.index }) { f in
                inkLine(f)
            }
        }
        if let b = ko.first(where: { $0.stage.kind == .bronze }) {
            inkLabel("Third place")
            inkLine(b)
        }
    }

    @ViewBuilder
    private var results: some View {
        let done = t.fixtures.filter { $0.status == .finished }.sorted { $0.kickoff < $1.kickoff }
        if done.isEmpty {
            Text("No results yet — kick-off at \(Clockface.time.string(from: t.start)).")
                .font(.copy(14, .semibold))
                .foregroundColor(Turf.inkHaze)
        }
        ForEach(done) { f in
            inkLine(f, showStage: true)
        }
    }

    private func inkLabel(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.copy(10, .heavy))
            .tracking(1.6)
            .foregroundColor(Turf.inkHaze)
            .padding(.top, 4)
    }

    private func inkLine(_ f: Fixture, showStage: Bool = false) -> some View {
        HStack(spacing: 6) {
            if showStage {
                Text(f.stage.code)
                    .font(.tally(10, .bold))
                    .foregroundColor(Turf.inkHaze)
                    .frame(width: 34, alignment: .leading)
            }
            Text(t.label(f.home))
                .font(.copy(13, f.winningSide == .home ? .heavy : .medium))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(1)
            Text(f.status == .scheduled ? "v" : "\(f.goals(.home))–\(f.goals(.away))")
                .font(.scoreboard(17))
                .frame(width: 46)
            Text(t.label(f.away))
                .font(.copy(13, f.winningSide == .away ? .heavy : .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
            if let s = f.shootout {
                Text("p\(s.home)-\(s.away)")
                    .font(.tally(9))
                    .foregroundColor(Turf.inkGold)
            }
        }
        .foregroundColor(Turf.ink)
    }
}
