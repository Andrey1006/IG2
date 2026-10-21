import SwiftUI

struct MatchBracketApp: View {
    @StateObject private var club = Clubhouse()

    var body: some View {
        Root()
            .environmentObject(club)
            .preferredColorScheme(.dark)
    }
}

struct Root: View {
    @EnvironmentObject private var club: Clubhouse

    var body: some View {
        ZStack {
            if club.tournament == nil {
                KickoffFlow()
                    .transition(.opacity)
            } else {
                Shell()
                    .transition(.asymmetric(insertion: .scale(scale: 1.04).combined(with: .opacity), removal: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.45), value: club.tournament == nil)
    }
}
