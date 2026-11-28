import AVFoundation
import SwiftUI
import SwiftData
import PhotosUI

struct AddCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var kanaText = ""
    @State private var selectedCategory: String
    @State private var selectedImage: UIImage?
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var errorAlert: ErrorAlert?

    let categories = Constants.allCategories

    /// 表示名・読みの問題。空白だけ・長すぎる場合は保存できない (#65)
    private var textProblem: CardExportImportService.CardProblem? {
        CardExportImportService.cardTextProblem(displayName: displayName, kanaText: kanaText)
    }

    /// - Parameter initialCategory: カテゴリの初期値。一覧にないものなら「場所」
    init(initialCategory: String = "場所") {
        _selectedCategory = State(
            initialValue: Constants.allCategories.contains(initialCategory) ? initialCategory : "場所"
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("画像") {
                    HStack {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(width: 80, height: 80)
                                .overlay {
                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .foregroundStyle(.gray)
                                }
                        }

                        VStack(spacing: 8) {
                            PhotosPicker(selection: $photosPickerItem, matching: .images) {
                                Label("写真を選ぶ", systemImage: "photo.on.rectangle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            CameraButton(showCamera: $showCamera)
                        }
                    }
                }

                Section {
                    TextField("表示名 (例: 公園)", text: $displayName)
                    TextField("読みがな (例: こうえん)", text: $kanaText)
                    Picker("カテゴリ", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                } header: {
                    Text("カード情報")
                } footer: {
                    // 空のときは保存ボタンを押せないだけにし、長すぎるときだけ理由を出す
                    if let problem = textProblem, problem == .displayNameTooLong || problem == .kanaTextTooLong {
                        Text(problem.message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("カードを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveCard() }
                        .disabled(textProblem != nil)
                }
            }
            // 選び直すと前の読み込みは自動でキャンセルされ、古い画像で上書きしない (#60)
            .task(id: photosPickerItem) {
                guard let item = photosPickerItem else { return }
                let data: Data?
                do {
                    data = try await item.loadTransferable(type: Data.self)
                } catch {
                    AppLog.image.error("Failed to load picked photo: \(error)")
                    data = nil
                }
                // フル解像度で展開しないよう、カード用の大きさに縮小デコードする
                var image: UIImage?
                if let data {
                    image = await Task.detached { ImageStorageService.pickedImage(from: data) }.value
                }
                guard !Task.isCancelled else { return }
                guard let image else {
                    errorAlert = .photoLoadFailed
                    return
                }
                selectedImage = image
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(image: $selectedImage)
                    .ignoresSafeArea()
            }
            .errorAlert($errorAlert)
        }
    }

    /// 画像やカードを保存できなかった場合は、カードを作らずにアラートを出して画面を開いたままにする
    /// （利用者が撮り直したり、もう一度保存したりできるように）(#38)
    private func saveCard() {
        let cardID = UUID()
        var descriptor = FetchDescriptor<PictureCard>(
            sortBy: [SortDescriptor(\PictureCard.sortOrder, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let nextSortOrder: Int
        do {
            nextSortOrder = (try modelContext.fetch(descriptor).first?.sortOrder ?? -1) + 1
        } catch {
            AppLog.data.error("Failed to fetch cards before adding: \(error)")
            errorAlert = .saveFailed(error)
            return
        }

        if let image = selectedImage {
            do {
                _ = try ImageStorageService.save(image: image, id: cardID)
            } catch {
                AppLog.image.error("Failed to save image for new card: \(error)")
                errorAlert = .imageSaveFailed(error)
                return
            }
        }

        let card = PictureCard(
            id: cardID,
            // 前後の空白や制御文字を除いた値で保存する (#65)
            displayName: CardExportImportService.sanitizedText(displayName),
            kanaText: CardExportImportService.sanitizedText(kanaText),
            category: selectedCategory,
            isPreset: false,
            sortOrder: nextSortOrder
        )
        modelContext.insert(card)
        do {
            try modelContext.save()
        } catch {
            AppLog.data.error("Failed to save new card: \(error)")
            modelContext.rollback()
            ImageStorageService.delete(id: cardID)
            errorAlert = .saveFailed(error)
            return
        }
        dismiss()
    }
}

// MARK: - Error alert

/// 追加・編集画面で出すエラーのアラート (#38)
struct ErrorAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    static func imageSaveFailed(_ error: Error) -> ErrorAlert {
        ErrorAlert(
            title: "画像を保存できませんでした",
            message: "もう一度撮影するか、別の写真を選んでください。\n（\(error.localizedDescription)）"
        )
    }

    static func saveFailed(_ error: Error) -> ErrorAlert {
        ErrorAlert(
            title: "保存できませんでした",
            message: "端末の空き容量を確認して、もう一度お試しください。\n（\(error.localizedDescription)）"
        )
    }

    static func deleteFailed(_ error: Error) -> ErrorAlert {
        ErrorAlert(
            title: "削除できませんでした",
            message: "もう一度お試しください。\n（\(error.localizedDescription)）"
        )
    }

    static let photoLoadFailed = ErrorAlert(
        title: "写真を読み込めませんでした",
        message: "別の写真を選んでください。iCloud の写真の場合は、通信できる状態でもう一度お試しください。"
    )
}

extension View {
    /// `alert` が nil でなくなったらアラートを表示し、閉じたら nil に戻す
    func errorAlert(_ alert: Binding<ErrorAlert?>) -> some View {
        self.alert(
            alert.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { alert.wrappedValue != nil },
                set: { if !$0 { alert.wrappedValue = nil } }
            ),
            presenting: alert.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }
}

// MARK: - Camera button

/// 「カメラで撮る」ボタン
///
/// `UIImagePickerController` はカメラが使えない環境（シミュレータ、カメラのない端末、
/// 機能制限でカメラを無効にした端末など）で `.camera` を指定するとクラッシュするため、
/// 使えないときはボタン自体を表示しない。カメラの権限が拒否されていれば設定 App へ案内する (#57)。
struct CameraButton: View {
    @Binding var showCamera: Bool

    @State private var permissionAlert: PermissionAlert?
    @Environment(\.openURL) private var openURL

    private enum PermissionAlert: Identifiable {
        case denied
        case restricted
        var id: Self { self }
    }

    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        if Self.isCameraAvailable {
            Button {
                openCamera()
            } label: {
                Label("カメラで撮る", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .alert(
                permissionAlert == .restricted ? "カメラを使用できません" : "カメラへのアクセスが許可されていません",
                isPresented: Binding(
                    get: { permissionAlert != nil },
                    set: { if !$0 { permissionAlert = nil } }
                ),
                presenting: permissionAlert
            ) { alert in
                if alert == .denied {
                    Button("設定を開く") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    Button("キャンセル", role: .cancel) {}
                } else {
                    Button("OK", role: .cancel) {}
                }
            } message: { alert in
                switch alert {
                case .denied:
                    Text("カメラで撮影するには、設定 App で Picton のカメラへのアクセスを許可してください。")
                case .restricted:
                    Text("この端末ではカメラの使用が制限されています。写真ライブラリから画像を選んでください。")
                }
            }
        }
    }

    private func openCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            Task { @MainActor in
                if await AVCaptureDevice.requestAccess(for: .video) {
                    showCamera = true
                } else {
                    permissionAlert = .denied
                }
            }
        case .denied:
            permissionAlert = .denied
        case .restricted:
            permissionAlert = .restricted
        @unknown default:
            // 未知の状態は UIImagePickerController 側の権限ダイアログに任せる
            showCamera = true
        }
    }
}

// MARK: - Camera UIViewControllerRepresentable

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                // フル解像度の写真を保存まで持ち続けないよう、すぐにカード用の大きさに縮小する (#60)
                parent.image = ImageStorageService.downscaled(uiImage)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
