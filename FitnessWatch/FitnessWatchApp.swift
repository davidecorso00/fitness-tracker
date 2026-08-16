import SwiftUI

@main
struct FitnessWatchApp: App {
    @StateObject private var session = WatchSessionStore.shared

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(session)
        }
    }
}
