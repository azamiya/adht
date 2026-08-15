import 'dart:math';

import '../models/task.dart';
import 'ai_client.dart';

/// AI クライアントのモック実装。
/// Gemini API キー未設定時と、API エラー時のフォールバックとして使う
/// （仕様 §2.2: オフラインでもタスク登録は完了できる — AI はあくまで補助）。
class MockAi implements AiClient {
  MockAi([Random? random]) : _random = random ?? Random();

  final Random _random;

  /// モックの応答遅延（実API感を出す）
  Duration get _latency => Duration(milliseconds: 700 + _random.nextInt(600));

  List<T> _pick<T>(List<T> pool, int n) {
    final copy = [...pool];
    final out = <T>[];
    while (out.length < n && copy.isNotEmpty) {
      out.add(copy.removeAt(_random.nextInt(copy.length)));
    }
    return out;
  }

  String _deadlineWord(Task t) => t.daysLeft < 0
      ? '期限を${-t.daysLeft}日超過'
      : t.daysLeft == 0
          ? '今日が期限'
          : 'あと${t.daysLeft}日';

  /// 同期版（シード生成やフォールバックで使用）
  List<String> suggestionsSync(Task task) {
    final t = task.title.replaceFirst(RegExp(r'を?(行う|やる|する)$'), '');
    final generic = [
      'タイマーを5分だけセットして、「$t」に関するメモを1行だけ書く',
      '「$t」でGoogle検索して、上から3件だけタイトルを眺める（読み込まない）',
      '完璧は禁止。60点でOKと宣言してから、関連するアプリやタブを1つだけ開く',
      '「$t」をもっと小さく割るなら？と自問して、思いついた小タスクを1つメモする',
      '終わったあとのご褒美を先に決める（コーヒー1杯など）。決めたら30秒だけ着手',
      '誰かに「今から$tやる」と宣言する（送らなくてもOK、下書きだけでも効く）',
    ];
    final left = [
      '「$t」のゴールを1文で書き出す（何ができたら完了？）',
      '今日は情報集めだけの回にする。判断は明日の自分に任せる',
      'メモアプリに比較表の枠だけ作る。中身は空でOK',
      '所要時間を見積もって、カレンダーに15分だけブロックを置く',
      '必要なもの（URL・書類・ツール）を1か所に集めるだけで今日は勝ち',
    ];
    final right = [
      '参考になりそうな事例を3つだけ眺めて、良いと思った点を1語ずつメモ',
      '下書き・ラフを「わざと雑に」1個作る。清書は別の日の自分がやる',
      '頭に浮かんだキーワードを1分間ひたすら書き出す（質は問わない）',
      '好きな曲を1曲かけて、曲が終わるまでだけ手を動かす',
      '一番ワクワクする部分から着手する。順番は無視してOK',
    ];

    final pool = [
      ...generic,
      ...(task.brainType == BrainType.leftBrain ? left : right),
    ];
    return _pick(pool, 3);
  }

  /// ユーザーの言葉を「最初の一歩」に軽く整える（v1.3: 入力支援に徹する）
  String polishStep(String userText) {
    final t = userText.trim().replaceFirst(RegExp(r'[。！!]$'), '');
    if (RegExp(r'^(まず|とりあえず|最初に)').hasMatch(t)) return t;
    return 'まず5分だけ「$t」をやってみる';
  }

  String replySync() {
    final replies = [
      'いいですね、それでいきましょう。下のボタンでそのまま決定できます',
      'それぐらい小さくて十分です。決めちゃいましょう',
      'OK、それを最初の一歩にしよか。ボタン押すだけやで',
    ];
    return replies[_random.nextInt(replies.length)];
  }

  /// ブリーフィング = 今日のまとめ ＋ 応援（v1.3）
  String briefingSync(List<Task> tasks, Tone tone) {
    final names = tasks.map((t) => '「${t.title}」').join('、');
    final dueNow = tasks.where((t) => t.daysLeft <= 0).toList();
    var summary = '今日は$namesの${tasks.length}本立て。';
    if (dueNow.isNotEmpty) {
      summary += '特に${dueNow.map((t) => '「${t.title}」').join('と')}は今日が期限です。';
    }
    final gentle = [
      '軽いものから5分だけ。それで十分前に進みます。応援してます！',
      '全部やらなくて大丈夫。1つ動いたら今日は勝ちです。頑張ろう！',
      '昨日の分は置いといて、今日の分だけでOK。あなたならいけます！',
    ];
    final tsukkomi = [
      'やり始めたら意外と進むやつやで。まず5分、応援しとるで！',
      '考える前にタイマー5分や。終わったら胸張ってええからな、頑張りや！',
      '一番軽いやつからでええねん。今日もぼちぼちいこか、応援してるで！',
    ];
    final rate = tone == Tone.tsukkomi ? 0.7 : 0.25;
    final pool = _random.nextDouble() < rate ? tsukkomi : gentle;
    return summary + pool[_random.nextInt(pool.length)];
  }

  /// AIに相談（v1.3）: タスク照会と気分相談に応じる
  String consultSync(List<Task> tasks, String text) {
    // tasks は軽い順で渡される前提
    if (RegExp(r'今日|明日|期限|締切|しめきり|やらないと|やるべき').hasMatch(text)) {
      final urgent = tasks.where((t) => t.daysLeft <= 1).toList();
      if (urgent.isEmpty) {
        return '今日明日が期限のタスクはありません。余裕のある日です ☕ もし進めるなら、一番軽いものを5分だけどうですか。';
      }
      final lines = urgent.map((t) {
        final when = t.daysLeft < 0
            ? '${-t.daysLeft}日超過'
            : t.daysLeft == 0
                ? '今日'
                : '明日';
        return '・${t.title}（${t.priority.label}・期限は$when）';
      }).join('\n');
      return '今日明日はこの${urgent.length}つです。軽い順に:\n$lines\nまずは一番上を5分だけ、どうですか。';
    }
    if (RegExp(r'だる|やる気|疲れ|しんど|眠い|むり|無理|めんどう|面倒').hasMatch(text)) {
      if (tasks.isEmpty) {
        return 'だるい日はそれでOK。タスクもゼロなので、今日は堂々と休みましょう。';
      }
      final lightest = tasks.first;
      return 'だるい日はそれでOKです。全部やらなくていい。\n'
          'もし1つだけなら、一番軽い「${lightest.title}」を。\n'
          '入口はこれだけ:「${lightest.displayFirstStep}」\n'
          '5分やってダメなら、今日は店じまいで正解です。';
    }
    if (RegExp(r'タスク|一覧|なにがある|何がある').hasMatch(text)) {
      if (tasks.isEmpty) return 'タスクはゼロです 🎉';
      final lines = tasks
          .map((t) => '・${t.title}（${t.priority.label}・${_deadlineWord(t)}）')
          .join('\n');
      return 'いま${tasks.length}件あります。軽い順に:\n$lines';
    }
    return 'なんでも聞いてください。「今日やらないといけないのは？」でタスクを整理したり、'
        '「だるくてやる気がしない」って気分をこぼしてもらってもOKです。';
  }

  @override
  Future<List<String>> generateSuggestions(Task task) async {
    await Future<void>.delayed(_latency);
    return suggestionsSync(task);
  }

  @override
  Future<ChatResult> chat(Task task, String userText) async {
    await Future<void>.delayed(
        Duration(milliseconds: 400 + _random.nextInt(400)));
    return ChatResult(reply: replySync(), proposal: polishStep(userText));
  }

  @override
  Future<String> briefingMessage(List<Task> tasks, Tone tone) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return briefingSync(tasks, tone);
  }

  @override
  Future<String> consult(List<Task> tasks, Tone tone, String userText) async {
    await Future<void>.delayed(
        Duration(milliseconds: 500 + _random.nextInt(400)));
    return consultSync(tasks, userText);
  }

  /// タスク単位の相談（v1.5）: 決定後の伴走役
  String taskConsultSync(Task t, String text) {
    final step = t.firstStep ?? '決めた一歩';
    if (RegExp(r'終わ|できた|完了|やった').hasMatch(text)) {
      return 'ナイス！🎉 進捗スライダーを上げておきましょう。全部終わったなら「完了する」ボタンでスパッと消しちゃってください';
    }
    if (RegExp(r'次|なにす|何す|どう進め|進め方|そのあと|その後').hasMatch(text)) {
      return 'いまの一歩は「$step」（進捗${t.progress}%）。それが済んだら、同じ要領で「次の5分」を決めるだけです。大きく考えなくてOK、刻んでいきましょう';
    }
    if (RegExp(r'詰ま|わからない|分からない|むず|難し|とまっ|止まっ').hasMatch(text)) {
      return '詰まったのは一歩がまだ大きいサインです。「${t.title}」の中で「これならできる」と思える部分だけ切り出しましょう。資料を開くだけ、1行書くだけ、でも前進です';
    }
    if (RegExp(r'だる|やる気|疲れ|しんど|むり|無理').hasMatch(text)) {
      return '無理しなくてOK。進捗${t.progress}%まで来てるのは事実です。今日は「$step」の半分だけでも勝ちにしましょう。ダメなら明日の自分に任せて店じまいで正解';
    }
    return '「${t.title}」の相談ですね。進め方でも気分でも何でもどうぞ。ちなみに決めた一歩は「$step」、いま進捗${t.progress}%です';
  }

  @override
  Future<String> taskConsult(Task task, String userText) async {
    await Future<void>.delayed(
        Duration(milliseconds: 400 + _random.nextInt(400)));
    return taskConsultSync(task, userText);
  }
}
