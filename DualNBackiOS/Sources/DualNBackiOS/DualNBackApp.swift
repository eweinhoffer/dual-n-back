import SwiftUI

@main
struct DualNBackApp: App {
    @StateObject private var game = GameEngine()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
            .environmentObject(game)
        }
    }
}
