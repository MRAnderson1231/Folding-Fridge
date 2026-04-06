import SwiftUI

@main
struct FoldingFridgeApp: App {
    @StateObject private var appModel = AppViewModel(service: ServiceFactory.makeService())

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
                .preferredColorScheme(.light)
        }
    }
}
