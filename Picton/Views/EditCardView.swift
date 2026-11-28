import SwiftUI
import PhotosUI

struct EditCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var card: PictureCard

    @State private var displayName: String
    @State private var kanaText: String
    @State private var selectedCategory: String
    /// 保存済みの画像（プレビュー表示用。保存時に書き戻さない）
    @State private var existingImage: UIImage?
    /// 写真選択・カメラで差し替えた画像。nil なら画像は変更しない
    @State private var newImage: UIImage?
    /// 「画像を削除」を押した。保存すると画像なしのカードになる (#46)
    @State private var removesImage = false
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showDeleteConfirmation = false
    @State private var isHidden: Bool
    @State private var errorAlert: ErrorAlert?

    let categories = Constants.allCategories

    /// 表示名・読みの問題。空白だけ・長すぎる場合は保存できない (#65)
    private var textProblem: CardExportImportService.CardProblem? {
        CardExportImportService.cardTextProblem(displayName: displayName, kanaText: kanaText)
    }

    init(card: PictureCard) {
        self.card = card
        _displayName = State(initialValue: card.displayName)
        _kanaText = State(initialValue: card.kanaText)
        _selectedCategory = State(initialValue: card.category)
        _isHidden = State(initialValue: card.isHidden)
    }

    private var previewImage: UIImage? {
        if let newImage { return newImage }
        return removesImage ? nil : existingImage
    }

    var body: some View {
        NavigationStack {
            Form {
                if !card.isPreset {
                    Section("画像") {
                        HStack {
                            if let image = previewImage {
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

                                if previewImage != nil {
                                    // 確定は「保存」時。押しただけではプレビューから消えるだけ
                                    Button(role: .destructive) {
                                        newImage = nil
                                        photosPickerItem = nil
                                        removesImage = true
                                    } label: {
                                        Label("画像を削除", systemImage: "trash")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    // 削除を押したあとに写真・カメラで選び直したら、そちらを使う
                    .onChange(of: newImage != nil) { _, hasNewImage in
                        if hasNewImage { removesImage = false }
                    }
                }

                Section {
                    TextField("表示名", text: $displayName)
                    TextField("読みがな", text: $kanaText)
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

                Section("表示設定") {
                    Toggle("このカードを非表示にする", isOn: $isHidden)
                }

                if !card.isPreset {
                    Section {
                        Button("このカードを削除", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle("カードを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveChanges() }
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
                newImage = image
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(image: $newImage)
                    .ignoresSafeArea()
            }
            .task {
                // 保存済みの画像はプレビューのためだけに非同期で読み込む
                guard !card.isPreset else { return }
                let id = card.id
                existingImage = await Task.detached { ImageStorageService.load(id: id) }.value
            }
            .errorAlert($errorAlert)
            .alert("カードを削除しますか？", isPresented: $showDeleteConfirmation) {
                Button("削除", role: .destructive) { deleteCard() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この操作は取り消せません")
            }
        }
    }

    /// 保存できなかった場合はアラートを出して画面を開いたままにする (#38)
    private func saveChanges() {
        // 画像を差し替えたときだけ保存する。保存済みの画像を毎回読み直して
        // 再圧縮すると、編集のたびに JPEG の画質が劣化するため (#55)。
        // 画像の保存に失敗したら、カードの内容も変更しない
        let replacesImage = !card.isPreset && newImage != nil
        if replacesImage, let image = newImage {
            do {
                _ = try ImageStorageService.save(image: image, id: card.id)
            } catch {
                AppLog.image.error("Failed to save image for card \(card.id, privacy: .public): \(error)")
                errorAlert = .imageSaveFailed(error)
                return
            }
        }

        // 画像の削除は、カードの保存に成功してからファイルを消す（失敗したら画像を残す）(#46)
        let deletesImage = !card.isPreset && !replacesImage && removesImage && existingImage != nil

        // 前後の空白や制御文字を除いた値で保存する (#65)
        card.displayName = CardExportImportService.sanitizedText(displayName)
        card.kanaText = CardExportImportService.sanitizedText(kanaText)
        card.category = selectedCategory
        card.isHidden = isHidden
        if replacesImage || deletesImage {
            // 一覧・文エリアのサムネイルに差し替え・削除を反映させる (#56)
            card.imageVersion += 1
        }

        do {
            try modelContext.save()
        } catch {
            AppLog.data.error("Failed to save card \(card.id, privacy: .public): \(error)")
            modelContext.rollback()
            errorAlert = .saveFailed(error)
            return
        }
        if deletesImage {
            ImageStorageService.delete(id: card.id)
        }
        dismiss()
    }

    /// 画像はカードの削除を保存できてから消す（失敗したときにカードだけ残って画像が消えないように）
    private func deleteCard() {
        let id = card.id
        modelContext.delete(card)
        do {
            try modelContext.save()
        } catch {
            AppLog.data.error("Failed to delete card \(id, privacy: .public): \(error)")
            modelContext.rollback()
            errorAlert = .deleteFailed(error)
            return
        }
        ImageStorageService.delete(id: id)
        dismiss()
    }
}
