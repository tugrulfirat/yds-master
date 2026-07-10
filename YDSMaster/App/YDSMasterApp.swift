import SwiftUI

@main
struct YDSMasterApp: App {
    @StateObject private var store = WordStore()
    @StateObject private var premium = PremiumStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(premium)
                .preferredColorScheme(.dark)
                .onReceive(premium.$isPremium) { store.isPremium = $0 }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: WordStore

    var body: some View {
        if store.profile.hasOnboarded {
            HomeView()
        } else {
            OnboardingView()
        }
    }
}

/// Identifies a game launch request (used by fullScreenCover).
struct GameLaunch: Identifiable, Hashable {
    let mode: GameMode
    let kind: SessionKind
    var id: String { "\(mode.rawValue)-\(kind.hashValue)" }
}
