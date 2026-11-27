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
    @State private var isImporting = false
    @State private var importCompleted = 0
    @State private var importTotal = 0

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
            .disabled(isImporting)
            .overlay {
                if isImporting {
                    ImportProgressView(completed: importCompleted, total: importTotal)
                }
            }
            .navigationTitle("データ管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .disabled(isImporting)
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
            // インポート中に閉じられないようにする
            .interactiveDismissDisabled(isImporting)
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

    /// 読み込み・画像処理はバックグラウンドで行い、その間は進捗を表示して操作を止める
    private func performImport(url: URL) {
        importCompleted = 0
        importTotal = 0
        isImporting = true
        Task {
            do {
                let result = try await CardExportImportService.importCards(
                    from: url,
                    context: modelContext
                ) { completed, total in
                    Task { @MainActor in
                        importCompleted = completed
                        importTotal = total
                    }
                }
                alertMessage = "\(result.importedCount) 枚のカードをインポートしました"
                if result.skippedImageCount > 0 {
                    alertMessage? += "\n\n\(result.skippedImageCount) 枚は画像を読み込めなかったため、画像なしで追加しました"
                }
            } catch {
                alertMessage = "インポート失敗: \(error.localizedDescription)"
            }
            isImporting = false
            showAlert = true
        }
    }
}

/// インポート中に画面を覆って表示する進捗
private struct ImportProgressView: View {
    let completed: Int
    let total: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                if total > 0 {
                    ProgressView(value: Double(completed), total: Double(total))
                    Text("インポート中… \(completed) / \(total) 枚")
                        .monospacedDigit()
                } else {
                    ProgressView()
                    Text("インポート中…")
                }
            }
            .font(.callout)
            .padding(24)
            .frame(maxWidth: 280)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .combine)
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
