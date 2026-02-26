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
            StatisticsView(
                sessions: game.statisticsHistory,
                onClearStatistics: { game.clearStatisticsHistory() }
            )
        }
        .windowResizability(.automatic)
        .defaultSize(width: 900, height: 640)
    }
}
