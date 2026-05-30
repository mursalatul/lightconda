import SwiftUI

@main
struct LightCondaApp: App {
    var body: some Scene {
        WindowGroup {
            AppView()
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
