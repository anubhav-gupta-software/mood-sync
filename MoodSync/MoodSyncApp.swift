import SwiftUI

@main
struct MoodSyncApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Theme.ink)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        model.scheduleSync(pushName: false)
                    }
                }
        }
    }
}
