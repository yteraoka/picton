import SwiftUI
import SwiftData

@main
struct PictonApp: App {
    let container: ModelContainer
    /// ストアを開けずに立ち直った場合の内容。起動後に利用者に知らせる (#40)
    private let recovery: PictonModelContainer.Recovery?
    @State private var showsRecoveryAlert: Bool

    init() {
        if Constants.isUITesting {
            // UI テストでは毎回まっさらな状態から始めるため、メモリ上のストアを使う
            do {
                container = try PictonModelContainer.make(isStoredInMemoryOnly: true)
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
            recovery = nil
        } else {
            let result = PictonModelContainer.makeRecovering()
            container = result.0
            recovery = result.1
        }
        _showsRecoveryAlert = State(initialValue: recovery != nil)

        PresetImageBootstrapper.bootstrapIfNeeded(context: container.mainContext)
        ImageStorageService.applyCompleteFileProtection()
        CardExportImportService.cleanUpExportDirectory()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .alert("保存されていたカードを読み込めませんでした", isPresented: $showsRecoveryAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(recoveryMessage)
                }
        }
        .modelContainer(container)
    }

    private var recoveryMessage: String {
        guard let recovery else { return "" }
        if recovery.isStoredInMemoryOnly {
            return "プリセットのカードで起動しました。このままでは追加・変更したカードは保存されません。端末の空き容量を確認して、アプリを起動し直してください。"
        }
        var message = "プリセットのカードで起動しました。カスタムカードはエクスポートしたZIPファイルからインポートし直せます。"
        if recovery.backupURL != nil {
            message += "\n\n読み込めなかったデータは端末内に残してあります。"
        }
        return message
    }
}
