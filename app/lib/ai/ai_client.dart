import '../models/task.dart';

/// チャット1往復の結果: 短い返事＋「最初の一歩」候補（仕様 §2.2 v1.3）。
/// チャットはユーザー入力の支援に徹し、A・B・C はいじらない。
class ChatResult {
  const ChatResult({required this.reply, required this.proposal});

  final String reply;
  final String proposal;
}

/// AI クライアントのインターフェース。
/// 実装: GeminiAi（本番）/ MockAi（キー未設定時・オフラインフォールバック）
abstract class AiClient {
  /// 着手の入口 A・B・C を生成（仕様 §2.2）
  Future<List<String>> generateSuggestions(Task task);

  /// チャット1往復: ユーザーの言葉を「最初の一歩」に整えて返す（仕様 §2.2 v1.3）
  Future<ChatResult> chat(Task task, String userText);

  /// ブリーフィング冒頭「ADHTからのコメント」= 今日のまとめ＋応援（仕様 §2.5 v1.3）
  Future<String> briefingMessage(List<Task> tasks, Tone tone);

  /// AIに相談: 全タスクを踏まえた横断チャット（仕様 §2.6 v1.3）
  Future<String> consult(List<Task> tasks, Tone tone, String userText);
}
