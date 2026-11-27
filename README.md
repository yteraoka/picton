# Picton - 絵カードコミュニケーションアプリ

<img src="docs/images/picton-icon.png" width="300">

発語障害のある子どもが、絵カードを並べて文を組み立て、音声読み上げで意思を伝えるための iOS アプリです。

## スクリーンショット

<img src="docs/images/screenshot-1.png" width="300">

## 特徴

- 50枚のプリセット絵カード（場所・動作・食べ物・人・生活・気持ち・手段）
- 「いつ」カテゴリでは「きょう・あした・あさって」やカレンダーから日付のカードを選べる（日曜・祝日は赤で表示）。「らいしゅう」などのカードを自分で追加することもできる
- カードをタップして文を組み立て、日本語音声で読み上げ
- カメラや写真ライブラリからオリジナルカードを作成（画像は中央を正方形に切り出して保存）
- カテゴリタブで素早くカードを探せる（左右スワイプでカテゴリ切り替え）
- 編集モードでカードの編集・追加と、ドラッグ&ドロップでの並べ替え
- 使わないカードは非表示にできる（プリセットも可。データ管理画面から再表示）
- カスタムカードのエクスポート/インポート（ZIP形式）
- 完全オフライン動作（サーバー不要）
- サイレントモードでも音声再生

## 動作環境

- iOS 17.0 以上
- Xcode 26 以上（`project.yml` の `xcodeVersion` と CI に合わせている）

## セットアップ

[xcodegen](https://github.com/yonaskolb/XcodeGen) を使って `.xcodeproj` を生成します。

```bash
# xcodegen のインストール（未インストールの場合）
brew install xcodegen

# プロジェクト生成
xcodegen generate
```

> **Note:** `Picton.xcodeproj` は `project.yml` から生成したものをコミットしています。ターゲットやビルド設定、ファイルの追加・削除は `project.yml` を編集して `xcodegen generate` してください（`project.pbxproj` を直接編集しない）。CI で両者が一致しているかを検査しています。

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
xcrun simctl launch "iPhone 17 Pro" me.teraoka.Picton
```

> **Note:** シミュレータ名は `xcrun simctl list devices available` で確認できます。

### 方法3: 実機 (iPhone) にインストール

#### 1. Apple ID の設定

Xcode で署名用のアカウントを設定します。

1. **Xcode** → **Settings** (`Cmd + ,`) → **Accounts** タブ
2. 左下の **+** → **Apple ID** を選択してログイン

#### 2. Signing の設定

1. Xcode で `Picton.xcodeproj` を開く
2. 左のナビゲータで **Picton** プロジェクト（青いアイコン）を選択
3. **Signing & Capabilities** タブを開く
4. **Automatically manage signing** にチェック
5. **Team** のドロップダウンから自分の Apple ID（`Personal Team`）を選択
6. **Bundle Identifier** が重複エラーになる場合は `me.teraoka.Picton` を一意の値に変更

> **Note:** Team と Bundle Identifier は `project.yml` で管理しています。自分のチームで恒久的に変えたい場合は `project.yml` の `DEVELOPMENT_TEAM` / `PRODUCT_BUNDLE_IDENTIFIER` を書き換えて `xcodegen generate` してください。

#### 3. iPhone を接続してビルド

1. iPhone を USB ケーブルで Mac に接続
2. iPhone 側で **「このコンピュータを信頼」** をタップ
3. Xcode 上部のデバイス選択で接続した **iPhone** を選択
4. **▶ (Run)** を押す（`Cmd + R`）

#### 4. 初回のみ: デバイスの信頼設定

無料の Apple ID で署名した場合、初回起動時にエラーが出ます。iPhone 側で以下の操作を行ってください。

1. **設定** → **一般** → **VPN とデバイス管理**
2. デベロッパ App の下に表示される自分の Apple ID をタップ
3. **「信頼」** をタップ

その後 Xcode から再度 Run するか、ホーム画面の Picton アイコンをタップして起動できます。

#### 無料 Apple ID と Apple Developer Program の違い

| 項目 | 無料 Apple ID | Apple Developer Program (年額 ¥15,800) |
|---|---|---|
| 実機インストール | 最大3台 | 100台 |
| アプリの有効期限 | **7日間**（再インストール要） | 1年間 |
| App Store 配布 | 不可 | 可能 |

無料の Apple ID でも開発・テスト目的での実機インストールは問題なくできますが、7日ごとに Xcode から再インストールが必要です。

## テスト

```bash
# ユニットテスト（Swift Testing）
xcodebuild test -project Picton.xcodeproj -scheme Picton \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PictonTests

# UI テスト（XCTest）
xcodebuild test -project Picton.xcodeproj -scheme Picton \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PictonUITests -parallel-testing-enabled NO
```

- UI テストは起動引数 `--uitesting` でアプリをインメモリストアで起動するため、シミュレータ上の既存データには影響しません
- Pull Request と main への push では GitHub Actions（`.github/workflows/ci.yml`）で
  `project.pbxproj` の生成チェック、ビルド、ユニットテスト、UI テストを実行します

## 使い方

1. **カードをタップ** → 画面上部の文エリアに追加され、そのカードを読み上げる
2. **▶ ボタン** → 並べたカードを日本語音声で読み上げ（読み上げ中は ■ で停止）
3. **文エリアのカードをタップ** → そのカードを削除
4. **文エリアのカードをドラッグ** → 順序を並び替え
5. **🗑 ボタン** → 文をすべてクリア
6. **カテゴリタブ** → 表示するカードを切り替え（左右スワイプでも切り替え可）
7. **「いつ」カテゴリ** → 「きょう・あした・あさって」をタップするか、カレンダーで日付を選んで「選択した日付」のカードをタップ。自分で追加した「いつ」のカードはその下の「追加したカード」に並ぶ
8. **左上の「編集」ボタン** → 編集モード（「完了」で終了）
   - **カードをタップ** → 表示名・読みがな・カテゴリの変更、非表示の設定（カスタムカードは画像の変更と削除も）
   - **カードをドラッグ** → 表示順を並べ替え
   - **グリッド末尾の「追加」** → カメラや写真からオリジナルカードを作成（カテゴリの初期値は表示中のタブ）
   - 編集モード中は左右スワイプでのカテゴリ切り替えは無効（タブで切り替える）
9. **右上の ⚙ ボタン** → データ管理
   - カスタムカードのエクスポート/インポート（ZIP形式）
   - 非表示にしたカードの一覧と再表示

## プロジェクト構成

```
Picton/
├── PictonApp.swift                 # エントリポイント、SwiftData設定
├── Models/
│   ├── PictureCard.swift           # SwiftData モデル
│   └── PresetCardData.swift        # プリセット定義一覧 (50枚)
├── Views/
│   ├── ContentView.swift           # ルートビュー（編集モード・カテゴリのスワイプ切り替え）
│   ├── SentenceAreaView.swift      # 文組み立てエリア
│   ├── SentenceCardView.swift      # 文内の個別カード
│   ├── CardGridView.swift          # カードグリッド（ドラッグ&ドロップ対応）
│   ├── CardGridItemView.swift      # グリッド内の個別カード
│   ├── CardImageView.swift         # カード画像の表示（プリセット画像 / SF Symbol / カスタム画像）
│   ├── WhenCategoryView.swift      # 「いつ」カテゴリの日付カード（グリッドのヘッダーとして表示）
│   ├── AddCardView.swift           # カスタムカード追加シート
│   ├── EditCardView.swift          # カスタムカード編集シート
│   ├── DataManagementView.swift    # データ管理（エクスポート/インポート、非表示カード）
│   ├── HiddenCardsListView.swift   # 非表示カードの一覧・再表示
│   └── PlaybackButtonView.swift    # 再生ボタン
├── ViewModels/
│   ├── SentenceViewModel.swift     # 文の組み立てロジック
│   └── CardLibraryViewModel.swift  # カード取得・フィルタ
├── Services/
│   ├── TTSService.swift            # AVSpeechSynthesizer ラッパー
│   ├── ImageStorageService.swift   # カスタム画像の保存・読込・削除
│   └── CardExportImportService.swift # ZIP形式エクスポート/インポート
├── Utilities/
│   ├── Constants.swift             # 定数定義
│   ├── JapaneseHolidayChecker.swift # 日本の祝日計算
│   └── PresetImageBootstrapper.swift # 起動時のプリセット投入・同期
├── Assets.xcassets/
└── PrivacyInfo.xcprivacy           # プライバシーマニフェスト
PictonTests/                        # ユニットテスト（Swift Testing）
PictonUITests/                      # UI テスト（XCTest）
```

## 技術スタック

- **SwiftUI** + **SwiftData** (データ永続化)
- **AVSpeechSynthesizer** (日本語TTS、オフライン対応)
- **PhotosUI** (写真選択) + **UIImagePickerController** (カメラ)
- **XcodeGen** (プロジェクト生成)
- プリセット画像は **SF Symbols** を使用
