import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/task.dart';
import 'ai_client.dart';
import 'mock_ai.dart';

/// Gemini API 実装（仕様 §6: 価格最優先 → flash-lite 系のエイリアスを使用）。
/// モデルは `gemini-flash-lite-latest` エイリアスで、引退・世代交代に自動追従する。
/// API エラー・オフライン時は MockAi にフォールバックする（仕様 §2.2）。
class GeminiAi implements AiClient {
  GeminiAi({required this.apiKey, MockAi? fallback})
      : fallback = fallback ?? MockAi();

  static const _model = 'gemini-flash-lite-latest';
  static const _timeout = Duration(seconds: 25);

  final String apiKey;
  final MockAi fallback;

  Uri get _endpoint => Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$apiKey');

  Future<String> _generate(String prompt, {bool json = false}) async {
    final res = await http
        .post(
          _endpoint,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              if (json) 'responseMimeType': 'application/json',
            },
          }),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw http.ClientException('Gemini API ${res.statusCode}: ${res.body}');
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    final text = decoded['candidates']?[0]?['content']?['parts']?[0]?['text'];
    if (text is! String || text.isEmpty) {
      throw const FormatException('Gemini API: empty response');
    }
    return text;
  }

  String _taskContext(Task task) {
    final brain = task.brainType == BrainType.rightBrain
        ? '右脳（創造・直感系）'
        : '左脳（論理・事務系）';
    final deadline = task.daysLeft < 0
        ? '期限を${-task.daysLeft}日超過'
        : task.daysLeft == 0
            ? '今日が期限'
            : 'あと${task.daysLeft}日';
    final chatLog = task.chat
        .map((m) => '${m.role == 'user' ? 'ユーザー' : 'AI'}: ${m.text}')
        .join('\n');
    return '''
タスク: ${task.title}
タイプ: $brain
Priority: ${task.priority.label}
期限: $deadline${chatLog.isEmpty ? '' : '\nこれまでの会話:\n$chatLog'}''';
  }

  static const _suggestionRules = '''
あなたはADHD当事者向けTodoアプリ「ADHT」のアシスタント。
タスクに対して「5分以内に始められる、小さく具体的な最初の一歩」を3案提案する。
ルール:
- 3案は順番のあるステップではなく、並列な選択肢（どれか1つ選べばいい）にする
- 各案は日本語1〜2文。命令口調ではなく、軽やかな提案の口調
- 完璧主義を外す・ハードルを下げる工夫を入れる（「〜だけ」「60点でOK」など）
- タスクのタイプに合わせる: 右脳なら感覚的・遊び心のある入口、左脳なら整理・構造化の入口
- 恥をかかせる表現・人格への評価は禁止''';

  List<String> _parseSuggestions(String jsonText) {
    final parsed = jsonDecode(jsonText);
    final list = parsed is List
        ? parsed
        : (parsed is Map ? parsed['suggestions'] : null);
    if (list is! List) throw const FormatException('suggestions not a list');
    final out = list.whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    if (out.length < 3) throw const FormatException('need 3 suggestions');
    return out.take(3).toList();
  }

  @override
  Future<List<String>> generateSuggestions(Task task) async {
    try {
      final text = await _generate('''
$_suggestionRules

${_taskContext(task)}

出力形式: JSON文字列配列のみ。例 ["案1","案2","案3"]''', json: true);
      return _parseSuggestions(text);
    } catch (_) {
      return fallback.suggestionsSync(task);
    }
  }

  @override
  Future<ChatResult> chat(Task task, String userText) async {
    try {
      final text = await _generate('''
$_suggestionRules

ユーザーはタスク詳細画面のチャットであなたに話しかけている。目的は、会話を通じて
タスクの解像度を上げ、「最初の一歩」を決められるようにすること。

${_taskContext(task)}

ユーザーの新しいメッセージ: $userText

やること:
1. メッセージへの返事を1〜3文の日本語で書く（親しみやすく、たまに軽い関西弁のツッコミも可。恥をかかせるのは禁止）
2. 会話全体を踏まえて A・B・C の3案を作り直す

出力形式: JSONオブジェクトのみ {"reply": "返事", "suggestions": ["案1","案2","案3"]}''',
          json: true);
      final parsed = jsonDecode(text);
      if (parsed is! Map) throw const FormatException('not an object');
      final reply = parsed['reply'];
      final suggestions = _parseSuggestions(jsonEncode(parsed));
      if (reply is! String || reply.trim().isEmpty) {
        throw const FormatException('empty reply');
      }
      return ChatResult(reply: reply.trim(), suggestions: suggestions);
    } catch (_) {
      return ChatResult(
        reply: fallback.replySync(userText),
        suggestions: fallback.suggestionsSync(task),
      );
    }
  }

  @override
  Future<String> briefingMessage(List<Task> tasks, Tone tone) async {
    final toneRule = tone == Tone.tsukkomi
        ? '口調: 軽い関西弁のツッコミ多め（例:「5分だけやで」）。ただし恥をかかせる・責める表現は絶対に禁止'
        : '口調: 基本やさしく具体的。2〜3割の確率で軽いユーモアやツッコミを混ぜてよい。恥をかかせる・責める表現は絶対に禁止';
    final taskLines = tasks
        .map((t) =>
            '- ${t.title}（${t.priority.label}、${t.daysLeft < 0 ? "期限${-t.daysLeft}日超過" : t.daysLeft == 0 ? "今日が期限" : "あと${t.daysLeft}日"}）')
        .join('\n');
    try {
      final text = await _generate('''
あなたはADHD当事者向けTodoアプリ「ADHT」の人格。朝のブリーフィング画面の冒頭コメントを書く。
読者はADHD当事者。プレッシャーではなく「入口」を渡すのが仕事。

今日の3タスク:
$taskLines

ルール:
- 日本語で1〜2文だけ。全タスクに触れなくてよい
- 「まず5分だけ」「1つだけでOK」のようにハードルを下げる
- 期限の事実（あと◯日）に触れるのはOK。人格への評価・恥・説教は禁止
- $toneRule

出力: コメント本文のみ（記号や引用符で囲まない）''');
      return text.trim();
    } catch (_) {
      return fallback.briefingSync(tasks.length, tone);
    }
  }
}
