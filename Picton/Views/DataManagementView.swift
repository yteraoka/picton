import SwiftUI
import SwiftData

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PictureCard.sortOrder) private var allCards: [PictureCard]

    @State private var exportURL: URL?
    @State private var isExporting = false
    @State private var showFileImporter = false
    @State private var alertMessage: String?
    @State private var showAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        performExport()
                    } label: {
                        Label("カスタムカードをエクスポート", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("エクスポート")
                } footer: {
                    let count = allCards.filter { !$0.isPreset }.count
                    Text("カスタムカード \(count) 枚をZIPファイルに保存します")
                }

                Section {
                    Button {
                        showFileImporter = true
                    } label: {
                        Label("ZIPファイルからインポート", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("インポート")
                } footer: {
                    Text("エクスポートしたZIPファイルを選択してカードを追加します")
                }

                Section {
                    NavigationLink {
                        HiddenCardsListView()
                    } label: {
                        Label("非表示カード", systemImage: "eye.slash")
                    }
                } footer: {
                    let count = allCards.filter { $0.isHidden }.count
                    Text("非表示のカード: \(count) 枚")
                }
            }
            .navigationTitle("データ管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $isExporting, onDismiss: removeExportedFile) {
                if let url = exportURL {
                    ShareSheet(url: url) {
                        // 共有完了・キャンセルのどちらでも呼ばれる
                        isExporting = false
                        removeExportedFile()
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.zip]
            ) { result in
                switch result {
                case .success(let url):
                    performImport(url: url)
                case .failure(let error):
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
            .alert("結果", isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private func performExport() {
        do {
            let url = try CardExportImportService.exportCustomCards(allCards)
            exportURL = url
            isExporting = true
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    /// 共有シートを閉じたらエクスポート ZIP を tmp に残さない
    private func removeExportedFile() {
        guard let url = exportURL else { return }
        CardExportImportService.removeExportedFile(at: url)
        exportURL = nil
    }

    private func performImport(url: URL) {
        do {
            let count = try CardExportImportService.importCards(from: url, context: modelContext)
            alertMessage = "\(count) 枚のカードをインポートしました"
            showAlert = true
        } catch {
            alertMessage = "インポート失敗: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

/// UIActivityViewController を SwiftUI から呼び出すラッパー
private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    var onComplete: () -> Void = {}

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        // 共有シートが閉じた後に呼ばれる（完了・キャンセルとも）
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
