import SwiftUI
import SwiftData

@main
struct PictonApp: App {
    let container: ModelContainer

    init() {
        do {
            // UI テストでは毎回まっさらな状態から始めるため、メモリ上のストアを使う
            container = try PictonModelContainer.make(isStoredInMemoryOnly: Constants.isUITesting)
            PresetImageBootstrapper.bootstrapIfNeeded(context: container.mainContext)
            ImageStorageService.applyCompleteFileProtection()
            CardExportImportService.cleanUpExportDirectory()
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
