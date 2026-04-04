import DualNBackCore
import SwiftUI

struct DualNBackPrototypeApp: App {
    @StateObject private var game = GameEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
        }
        .defaultSize(width: 620, height: 760)
        .windowResizability(.automatic)

        Window("Statistics", id: "statistics") {
            StatisticsView()
                .environmentObject(game)
        }
        .windowResizability(.automatic)
        .defaultSize(width: 900, height: 640)
    }
}
