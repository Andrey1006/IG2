import SwiftUI
import Combine

enum Tab: Int, CaseIterable {
    case fixtures, table, whistle, leaders, desk

    var title: String {
        switch self {
        case .fixtures: return "Fixtures"
        case .table: return "Table"
        case .whistle: return "Whistle"
        case .leaders: return "Leaders"
        case .desk: return "Desk"
        }
    }

    var glyph: TabGlyph {
        switch self {
        case .fixtures: return .fixtures
        case .table: return .table
        case .whistle: return .whistle
        case .leaders: return .leaders
        case .desk: return .desk
        }
    }
}

enum Route: Hashable {
    case fixture(UUID)
    case team(UUID)
    case player(UUID)
    case rules
    case hall
}

@MainActor
final class Dugout: ObservableObject {
    @Published var tab = Tab.fixtures
    @Published var paths: [Tab: [Route]] = [:]
    @Published var focus: UUID?
    @Published var posterOpen = false

    func path(_ tab: Tab) -> Binding<[Route]> {
        Binding(get: { self.paths[tab] ?? [] }, set: { self.paths[tab] = $0 })
    }

    func whistle(_ fixture: UUID) {
        focus = fixture
        paths[.whistle] = []
        tab = .whistle
    }
}

struct Shell: View {
    @StateObject private var dugout = Dugout()

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $dugout.tab) {
                stack(.fixtures) { FixturesScreen() }
                stack(.table) { TableScreen() }
                stack(.whistle) { WhistleScreen() }
                stack(.leaders) { LeadersScreen() }
                stack(.desk) { DeskScreen() }
            }

            if (dugout.paths[dugout.tab] ?? []).isEmpty {
                TabStrip(selection: $dugout.tab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: (dugout.paths[dugout.tab] ?? []).isEmpty)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .environmentObject(dugout)
    }

    private func stack<Content: View>(_ tab: Tab, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack(path: dugout.path(tab)) {
            content()
                .toolbar(.hidden, for: .navigationBar)
                .routes()
        }
        .toolbar(.hidden, for: .tabBar)
        .tag(tab)
    }
}

private struct TabStrip: View {
    @Binding var selection: Tab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    if selection != tab { Buzz.tick() }
                    selection = tab
                } label: {
                    VStack(spacing: 5) {
                        tab.glyph.image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(selection == tab ? Turf.floodlight : Turf.haze.opacity(0.8))
                            .scaleEffect(selection == tab ? 1.08 : 1)
                        Text(tab.title)
                            .font(.copy(10, .heavy))
                            .foregroundColor(selection == tab ? Turf.chalk : Turf.haze.opacity(0.8))
                        ZStack {
                            if selection == tab {
                                Capsule()
                                    .fill(Turf.floodlight)
                                    .matchedGeometryEffect(id: "spot", in: ns)
                            }
                        }
                        .frame(width: 18, height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: selection)
        .padding(.horizontal, 8)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .background(
            Turf.night
                .overlay(Rectangle().fill(Turf.line).frame(height: 1), alignment: .top)
                .shadow(color: .black.opacity(0.35), radius: 14, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

extension View {
    func routes() -> some View {
        navigationDestination(for: Route.self) { route in
            Group {
                switch route {
                case .fixture(let id): MatchSheetScreen(fixtureID: id)
                case .team(let id): TeamScreen(teamID: id)
                case .player(let id): PlayerScreen(playerID: id)
                case .rules: RulesScreen()
                case .hall: HallScreen()
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    func turfScreen() -> some View {
        frame(maxWidth: Turf.column)
            .frame(maxWidth: .infinity)
            .background(Mown(bands: 7).ignoresSafeArea())
    }
}

struct BackBar: View {
    let title: String
    var trailing: AnyView?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(Turf.chalk)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Turf.pitch))
            }
            .buttonStyle(Squash())
            Text(title.uppercased())
                .font(.copy(13, .heavy))
                .tracking(1.8)
                .foregroundColor(Turf.haze)
                .lineLimit(1)
            Spacer()
            if let trailing { trailing }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }
}

extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
