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

  String _deadlineWord(Task t) => t.daysLeft < 0
      ? '期限を${-t.daysLeft}日超過'
      : t.daysLeft == 0
          ? '今日が期限'
          : 'あと${t.daysLeft}日';

  String _taskContext(Task task) {
    final brain = task.brainType == BrainType.rightBrain
        ? '右脳（創造・直感系）'
        : '左脳（論理・事務系）';
    return '''
タスク: ${task.title}
タイプ: $brain
Priority: ${task.priority.label}
期限: ${_deadlineWord(task)}''';
  }

  String _taskListContext(List<Task> tasks) => tasks
      .map((t) =>
          '- ${t.title}（${t.priority.label}、${_deadlineWord(t)}${t.firstStep != null ? '、決定済みの最初の一歩: ${t.firstStep}' : ''}）')
      .join('\n');

  String _toneRule(Tone tone) => tone == Tone.tsukkomi
      ? '口調: 軽い関西弁のツッコミ多め（例:「5分だけやで」）。ただし恥をかかせる・責める表現は絶対に禁止'
      : '口調: 基本やさしく具体的。2〜3割の確率で軽いユーモアを混ぜてよい。恥をかかせる・責める表現は絶対に禁止';

  static const _adhtPersona = '''
あなたはADHD当事者向けTodoアプリ「ADHT」の人格。
読者はADHD当事者。プレッシャーではなく「入口」を渡すのが仕事。
恥をかかせる表現・人格への評価・説教は禁止。''';

  @override
  Future<List<String>> generateSuggestions(Task task) async {
    try {
      final text = await _generate('''
$_adhtPersona
タスクに対して「5分以内に始められる、小さく具体的な最初の一歩」を3案提案する。
ルール:
- 3案は順番のあるステップではなく、並列な選択肢（どれか1つ選べばいい）にする
- 各案は日本語1〜2文。命令口調ではなく、軽やかな提案の口調
- 完璧主義を外す・ハードルを下げる工夫を入れる（「〜だけ」「60点でOK」など）
- タスクのタイプに合わせる: 右脳なら感覚的・遊び心のある入口、左脳なら整理・構造化の入口

${_taskContext(task)}

出力形式: JSON文字列配列のみ。例 ["案1","案2","案3"]''', json: true);
      final parsed = jsonDecode(text);
      if (parsed is! List) throw const FormatException('not a list');
      final out =
          parsed.whereType<String>().where((s) => s.trim().isNotEmpty).toList();
      if (out.length < 3) throw const FormatException('need 3');
      return out.take(3).toList();
    } catch (_) {
      return fallback.suggestionsSync(task);
    }
  }

  @override
  Future<ChatResult> chat(Task task, String userText) async {
    try {
      final text = await _generate('''
$_adhtPersona
ユーザーはタスク詳細画面のチャットで、自分がやれそうなことを自分の言葉で書いた。
あなたの仕事は凝った提案を考えることではなく、ユーザーの言葉をほぼそのまま
「最初の一歩」として軽く整えること（勝手に内容を変えたり膨らませたりしない）。

${_taskContext(task)}

ユーザーの言葉: $userText

やること:
1. proposal: ユーザーの言葉を最初の一歩に整える（例: 入力「レシートを机に出すだけ」→「まず5分だけ『レシートを机に出すだけ』をやってみる」）。1文まで
2. reply: 1〜2文の短い後押し（決定ボタンで確定できることに触れる）

出力形式: JSONオブジェクトのみ {"reply": "...", "proposal": "..."}''', json: true);
      final parsed = jsonDecode(text);
      if (parsed is! Map) throw const FormatException('not an object');
      final reply = parsed['reply'];
      final proposal = parsed['proposal'];
      if (reply is! String || proposal is! String || proposal.trim().isEmpty) {
        throw const FormatException('bad fields');
      }
      return ChatResult(reply: reply.trim(), proposal: proposal.trim());
    } catch (_) {
      return ChatResult(
        reply: fallback.replySync(),
        proposal: fallback.polishStep(userText),
      );
    }
  }

  @override
  Future<String> briefingMessage(List<Task> tasks, Tone tone) async {
    try {
      final text = await _generate('''
$_adhtPersona
朝のブリーフィング画面の冒頭コメントを書く。構成は「今日のまとめ＋応援」の2部:
1. 今日の持ちタスク（下記、軽い順）をざっくり要約。今日が期限のものは名指しする
2. 「まず5分だけ」「1つ動いたら今日は勝ち」のようにハードルを下げる応援で締める

今日の${tasks.length}タスク（軽い順）:
${_taskListContext(tasks)}

ルール:
- 日本語で2〜3文
- 期限の事実（今日が期限など）に触れるのはOK
- ${_toneRule(tone)}

出力: コメント本文のみ（記号や引用符で囲まない）''');
      return text.trim();
    } catch (_) {
      return fallback.briefingSync(tasks, tone);
    }
  }

  @override
  Future<String> consult(List<Task> tasks, Tone tone, String userText) async {
    try {
      final text = await _generate('''
$_adhtPersona
ここは「AIに相談」タブ。ユーザーはタスクのことでも気分のことでも自由に話しかけてくる。

いまの全タスク（軽い順）:
${tasks.isEmpty ? '（タスクなし）' : _taskListContext(tasks)}

ユーザーのメッセージ: $userText

答え方:
- タスクの照会（今日明日の期限など）なら、該当タスクを軽い順で挙げ、最初の一歩を1つ添える
- 気分の相談（だるい・やる気がしない等）なら、まず受け止めて「全部やらなくていい」と肯定し、
  一番軽いタスクの入口を1つだけ差し出す。やらない選択も肯定する
- それ以外は短く親身に。長い説教は禁止
- 日本語で5文以内。箇条書き可
- ${_toneRule(tone)}

出力: 返答本文のみ''');
      return text.trim();
    } catch (_) {
      return fallback.consultSync(tasks, userText);
    }
  }

  @override
  Future<String> taskConsult(Task task, String userText) async {
    final chatLog = task.chat
        .map((m) => '${m.role == 'user' ? 'ユーザー' : 'AI'}: ${m.text}')
        .join('\n');
    try {
      final text = await _generate('''
$_adhtPersona
ユーザーは「最初の一歩」を決めたあと、このタスク専属の相談チャットで話しかけている。
あなたはこのタスクの伴走役。

${_taskContext(task)}
決定した最初の一歩: ${task.firstStep ?? '（未決定）'}
進捗度: ${task.progress}%
${chatLog.isEmpty ? '' : 'これまでの会話:\n$chatLog\n'}
ユーザーのメッセージ: $userText

答え方:
- 進め方の相談（次は何を？等）→ 決めた一歩と進捗を踏まえて「次の5分」を1つだけ示す
- 詰まった・難しい → 一歩をさらに小さく割る具体案を1つ
- だるい・やる気がない → まず受け止め、進捗の事実を肯定し、半分だけ等のハードル下げを提案
- 終わった・できた → 称賛し、進捗スライダーの更新か「完了」ボタンを促す
- 日本語で1〜3文。説教・恥をかかせる表現は禁止

出力: 返答本文のみ''');
      return text.trim();
    } catch (_) {
      return fallback.taskConsultSync(task, userText);
    }
  }
}
