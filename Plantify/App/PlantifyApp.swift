import SwiftUI
import SwiftData

@main
struct PlantifyApp: App {

    @StateObject private var services: AppServices

    init() {
        let services = AppServices.live()
        _services = StateObject(wrappedValue: services)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(services)
                .modelContainer(services.container)
        }
    }
}
