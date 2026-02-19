import SwiftUI
import PhotosUI

struct EditCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var card: PictureCard

    @State private var displayName: String
    @State private var kanaText: String
    @State private var selectedCategory: String
    @State private var selectedImage: UIImage?
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showDeleteConfirmation = false
    @State private var isHidden: Bool

    let categories = Constants.allCategories.filter { $0 != "すべて" }

    init(card: PictureCard) {
        self.card = card
        _displayName = State(initialValue: card.displayName)
        _kanaText = State(initialValue: card.kanaText)
        _selectedCategory = State(initialValue: card.category)
        _isHidden = State(initialValue: card.isHidden)
        if !card.isPreset {
            _selectedImage = State(initialValue: ImageStorageService.load(id: card.id))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if !card.isPreset {
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

                                Button {
                                    showCamera = true
                                } label: {
                                    Label("カメラで撮る", systemImage: "camera")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                Section("カード情報") {
                    TextField("表示名", text: $displayName)
                    TextField("読みがな", text: $kanaText)
                    Picker("カテゴリ", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
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
                        .disabled(displayName.isEmpty || kanaText.isEmpty)
                }
            }
            .onChange(of: photosPickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(image: $selectedImage)
                    .ignoresSafeArea()
            }
            .alert("カードを削除しますか？", isPresented: $showDeleteConfirmation) {
                Button("削除", role: .destructive) { deleteCard() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この操作は取り消せません")
            }
        }
    }

    private func saveChanges() {
        card.displayName = displayName
        card.kanaText = kanaText
        card.category = selectedCategory
        card.isHidden = isHidden

        if !card.isPreset, let image = selectedImage {
            _ = try? ImageStorageService.save(image: image, id: card.id)
        }

        try? modelContext.save()
        dismiss()
    }

    private func deleteCard() {
        ImageStorageService.delete(id: card.id)
        modelContext.delete(card)
        try? modelContext.save()
        dismiss()
    }
}
