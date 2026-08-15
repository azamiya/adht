import '../models/task.dart';

/// チャット1往復の結果: AIの返事＋作り直したA・B・C
class ChatResult {
  const ChatResult({required this.reply, required this.suggestions});

  final String reply;
  final List<String> suggestions;
}

/// AI クライアントのインターフェース。
/// 実装: GeminiAi（本番）/ MockAi（キー未設定時・オフラインフォールバック）
abstract class AiClient {
  /// 着手の入口 A・B・C を生成（仕様 §2.2）
  Future<List<String>> generateSuggestions(Task task);

  /// チャット1往復: 返事と、会話を踏まえて作り直した A・B・C（仕様 §2.2）
  Future<ChatResult> chat(Task task, String userText);

  /// ブリーフィング冒頭「ADHTからのコメント」（仕様 §2.5）
  Future<String> briefingMessage(List<Task> tasks, Tone tone);
}
