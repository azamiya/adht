# ADHT — Claude Code 向けプロジェクトガイド

ADHT（Attention Deficit Hyperactivity Todo）は ADHD 当事者（安谷屋個人）向けの Todo アプリ。
仕様書・HTMLプロトタイプ・Flutter アプリ本体を同一リポジトリで管理する。

## ⚠️ 開発フロー（最重要ルール）

新しいタスク（機能追加・変更）は**必ずこの順番**で進める。飛ばさないこと。

1. **仕様書とHTMLプロトタイプを先に更新する**
   - 仕様書: [docs/index.html](docs/index.html)
   - プロトタイプ: [docs/prototype/](docs/prototype/)（`file://` で動く。AIはモック）
2. **安谷屋がレビューする** — レビュー完了まで待つ。**この段階ではアプリ本体（app/）に手を付けない**
3. **レビュー完了後、安谷屋の指示を受けてから** Flutter アプリ（app/）を実装し、実機ビルドを行う

つまり「仕様・プロトタイプ更新 → レビュー → 指示 → アプリ化・実機」。
アプリ改修の指示が先に来た場合も、仕様書・プロトタイプが未更新ならまずそちらを更新して確認を取る。

## バージョニング

- **セマンティック バージョニング 2.0.0** 準拠（メジャー=非互換 / マイナー=後方互換の機能追加 / パッチ=後方互換のバグ修正）。修正ごとに更新
- **仕様書とアプリのバージョンを揃える**（仕様書 v1.4 ⇔ アプリ v1.4.x。パッチは実装側のみ進んでよい）
- 更新箇所: 仕様書メタ情報 / プロトタイプ `APP_VERSION`（prototype.js） / `app/pubspec.yaml` / `kAppVersion`（settings_screen.dart）
- エクスポートJSONの形式バージョンは別番号（現在 version 2）。**旧→新インポートは常にサポート、ダウングレードインポートは非対応**

## リポジトリ構成

| パス | 内容 |
| --- | --- |
| docs/index.html | 仕様書（唯一の要件ソース。変更はまずここ） |
| docs/prototype/ | 動くHTMLプロトタイプ（iPhone 17モック。デザインの正） |
| app/ | Flutter アプリ本体（iOS先行、Android予定） |
| app/lib/ai/ | AI層。`AiClient` インターフェース、`GeminiAi`（本番）/ `MockAi`（フォールバック） |

## 秘密情報

- **`app/lib/secrets.dart`（Gemini APIキー）は .gitignore 済み。絶対にコミットしない**。コミット前に毎回 `git check-ignore app/lib/secrets.dart` で確認する習慣を維持
- 新環境では `app/lib/secrets.example.dart` をコピーしてキーを設定（空ならモック動作）

## よく使うコマンド

```bash
# 静的チェック（app/ で実行）
flutter analyze

# シミュレータ確認（ADHT iPhone 17 / iOS 26.5）
flutter build ios --simulator
xcrun simctl install FF806DBF-727C-4875-83DD-C5114BF80DB9 build/ios/iphonesimulator/Runner.app
xcrun simctl launch FF806DBF-727C-4875-83DD-C5114BF80DB9 com.adawarp.adht1

# 実機インストール（AdaiPhone / iPhone 17e。要ロック解除）
flutter run --release -d 00008150-001931640A7B401C
```

- Bundle ID: `com.adawarp.adht1`（無料Personal Team `7C4296689U` 署名。**7日で期限切れ** → 再インストールで復活）
- プロトタイプの動作確認: ヘッドレスChromeでスクリーンショット（`#list` `#detail` `#consult` `#settings` ハッシュで各画面を直接開ける）

## コミット規約

- conventional commits（`feat(app):` `feat(docs):` `chore(ios):` など）、日本語1行サマリ＋本文に箇条書き
- コミット・プッシュは安谷屋の指示があったときに行う
