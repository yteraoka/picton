import SwiftUI
import SwiftData

@main
struct PictonApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: PictureCard.self)
            PresetImageBootstrapper.bootstrapIfNeeded(context: container.mainContext)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
