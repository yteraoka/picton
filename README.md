# Picton - 絵カードコミュニケーションアプリ

発語障害のある子どもが、絵カードを並べて文を組み立て、音声読み上げで意思を伝えるための iOS アプリです。

## 特徴

- 45枚のプリセット絵カード（場所・動作・気持ち・食べ物・人・生活）
- カードをタップして文を組み立て、日本語音声で読み上げ
- ドラッグ&ドロップでカードの並び替え
- カメラや写真ライブラリからオリジナルカードを作成
- カテゴリフィルタで素早くカードを探せる
- 完全オフライン動作（サーバー不要）
- サイレントモードでも音声再生

## 動作環境

- iOS 17.0 以上
- Xcode 16.0 以上

## セットアップ

[xcodegen](https://github.com/yonaskolb/XcodeGen) を使って `.xcodeproj` を生成します。

```bash
# xcodegen のインストール（未インストールの場合）
brew install xcodegen

# プロジェクト生成
xcodegen generate
```

## 実行方法

### 方法1: Xcode から実行（推奨）

```bash
open Picton.xcodeproj
```

1. Xcode 上部のデバイス選択でシミュレータ（例: iPhone 17 Pro）を選択
2. **▶ (Run)** ボタンを押す（または `Cmd + R`）

デバッグコンソールやホットリロードが利用できます。

### 方法2: コマンドラインから実行

```bash
# ビルド
xcodebuild -project Picton.xcodeproj -scheme Picton \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build build

# シミュレータを起動
xcrun simctl boot "iPhone 17 Pro"
open -a Simulator

# アプリをインストール & 起動
xcrun simctl install "iPhone 17 Pro" \
  build/Build/Products/Debug-iphonesimulator/Picton.app
xcrun simctl launch "iPhone 17 Pro" com.yteraoka.Picton
```

> **Note:** シミュレータ名は `xcrun simctl list devices available` で確認できます。

## 使い方

1. **カードをタップ** → 画面上部の文エリアに追加される
2. **▶ ボタン** → 並べたカードを日本語音声で読み上げ
3. **文エリアのカードをタップ** → そのカードを削除
4. **文エリアのカードをドラッグ** → 順序を並び替え
5. **🗑 ボタン** → 文をすべてクリア
6. **カテゴリタブ** → 表示するカードをフィルタリング
7. **＋ ボタン** → カメラや写真からオリジナルカードを作成
8. **カードを長押し** → カードの編集・削除

## プロジェクト構成

```
Picton/
├── PictonApp.swift                 # エントリポイント、SwiftData設定
├── Models/
│   ├── PictureCard.swift           # SwiftData モデル
│   └── PresetCardData.swift        # プリセット定義一覧 (45枚)
├── Views/
│   ├── ContentView.swift           # ルートビュー
│   ├── SentenceAreaView.swift      # 文組み立てエリア
│   ├── SentenceCardView.swift      # 文内の個別カード
│   ├── CardGridView.swift          # カードグリッド
│   ├── CardGridItemView.swift      # グリッド内の個別カード
│   ├── AddCardView.swift           # カスタムカード追加シート
│   ├── EditCardView.swift          # カスタムカード編集シート
│   └── PlaybackButtonView.swift    # 再生ボタン
├── ViewModels/
│   ├── SentenceViewModel.swift     # 文の組み立てロジック
│   └── CardLibraryViewModel.swift  # カード取得・フィルタ
├── Services/
│   ├── TTSService.swift            # AVSpeechSynthesizer ラッパー
│   └── ImageStorageService.swift   # カスタム画像の保存・読込・削除
├── Utilities/
│   ├── Constants.swift             # 定数定義
│   └── PresetImageBootstrapper.swift # 初回起動時プリセット投入
└── Assets.xcassets/
```

## 技術スタック

- **SwiftUI** + **SwiftData** (データ永続化)
- **AVSpeechSynthesizer** (日本語TTS、オフライン対応)
- **PhotosUI** (写真選択) + **UIImagePickerController** (カメラ)
- **XcodeGen** (プロジェクト生成)
- プリセット画像は **SF Symbols** を使用
