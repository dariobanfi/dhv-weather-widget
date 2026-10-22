import SwiftUI

@main
struct DHVWeatherApp: App {
    @State private var store = ForecastStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .onOpenURL { store.open($0) }
                .task(id: scenePhase) {
                    if scenePhase == .active { await store.refresh(maxAge: 5 * 60) }
                }
        }
    }
}
