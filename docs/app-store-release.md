# App Store 公開手順

## 1. Apple Developer Program への登録

- [developer.apple.com](https://developer.apple.com) で年間 $99 の有料メンバーシップに登録

## 2. App Store Connect の設定

- [appstoreconnect.apple.com](https://appstoreconnect.apple.com) でアプリを新規作成
- Bundle ID を登録（Xcode のプロジェクト設定と一致させる）
- アプリ名、説明文、キーワード、カテゴリを入力
- スクリーンショットを用意（iPhone 6.5インチ、6.7インチなど必須サイズあり）
- プライバシーポリシー URL を用意（外部 URL が必要）

## 3. Xcode でのビルド設定

- `Signing & Capabilities` で Team を Developer Account に設定
- Bundle Identifier を App Store Connect と一致させる
- バージョン番号とビルド番号を設定
- `Any iOS Device` を選択して Archive ビルド

```
Product → Archive
```

## 4. TestFlight での事前テスト（推奨）

- Archive 後に `Distribute App` → `App Store Connect` でアップロード
- TestFlight で実機テストを行い問題がないか確認

## 5. 審査提出

- App Store Connect でビルドを選択してレビューに提出
- 審査には通常 1〜3 日かかる

## 6. 審査でよく引っかかるポイント

- **プライバシーポリシー**: 必須
- **権限の説明**: カメラ・マイクなど使用する権限の `NSCameraUsageDescription` 等が適切か
- **クラッシュ**: 審査中にクラッシュすると即リジェクト
- **メタデータ**: スクリーンショットとアプリの実際の動作が一致しているか

## このアプリ固有の確認事項

- カメラ権限の `NSCameraUsageDescription` が `Info.plist` に記載されているか確認
- 子供向けアプリの場合、年齢レーティングの設定に注意
