import 'dart:math';

import '../models/task.dart';

/// AI クライアントのモック実装。
/// マイルストーン3で Gemini API 呼び出しに差し替える（インターフェースは維持）。
class MockAi {
  MockAi([Random? random]) : _random = random ?? Random();

  final Random _random;

  List<T> _pick<T>(List<T> pool, int n) {
    final copy = [...pool];
    final out = <T>[];
    while (out.length < n && copy.isNotEmpty) {
      out.add(copy.removeAt(_random.nextInt(copy.length)));
    }
    return out;
  }

  /// 着手の入口 A・B・C を生成（仕様 §2.2: 常に並列な3案）
  List<String> generateSuggestions(Task task) {
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
    final userMsgs = task.chat
        .where((m) => m.role == 'user')
        .map((m) => m.text)
        .toList();
    final ctx = userMsgs.length > 2
        ? userMsgs.sublist(userMsgs.length - 2).join('、')
        : userMsgs.join('、');

    final picked = _pick(pool, ctx.isEmpty ? 3 : 2);
    if (ctx.isNotEmpty) {
      picked.insert(0, '「$ctx」を踏まえて: まずその条件で「$t」の選択肢を1つだけ探してみる');
    }
    return picked.take(3).toList();
  }

  /// チャットへの返事（仕様 §2.2: 提案の作り直しを伝える）
  String chatReply(String userText) {
    final replies = [
      'なるほど、「$userText」ですね。それ前提で上の入口を出し直しました。今なら A が一番ハードル低いと思います',
      'OK、条件に入れました。上の A・B・C を更新したので、ピンとくるものだけ見てください',
      '了解です。それを踏まえて入口を作り直しました。完璧じゃなくてOK、まず5分だけが合言葉です',
      'ええやん、だいぶ具体的になってきた。上の3つ、どれか1個だけ選んでみて',
    ];
    return replies[_random.nextInt(replies.length)];
  }

  /// ブリーフィング冒頭の「ADHTからのコメント」（仕様 §2.5: ハイブリッド口調）
  String briefingMessage(int taskCount, Tone tone) {
    final gentle = [
      'おはようございます。今日はこの$taskCountつだけでOKです。1つ目の「最初の一歩」だけ、どうですか？',
      '全部やらなくて大丈夫。上から順じゃなくて、一番ラクそうなものから始めてOKです。',
      '今日の持ち時間は有限。だから$taskCountつに絞りました。5分だけ始めたら、あとは勝手に進みます。',
    ];
    final tsukkomi = [
      'おはようさん。見て見ぬふりリスト、今日で1個減らそか。まずは$taskCountつ中どれか1つ、5分だけやで。',
      'はいはい、タブ100個開く前にこれ見て。今日は$taskCountつだけ。最初の一歩は用意しといたで。',
      'やる気が出るのを待っとっても来ぉへんで。5分だけ動いたらやる気が後から来るやつや。',
    ];
    // ハイブリッド: 基本やさしめ、ツッコミ設定なら確率を上げる。恥・人格否定はどちらにも無し。
    final tsukkomiRate = tone == Tone.tsukkomi ? 0.7 : 0.25;
    final pool = _random.nextDouble() < tsukkomiRate ? tsukkomi : gentle;
    return pool[_random.nextInt(pool.length)];
  }

  /// モックの応答遅延（実API感を出す）
  Duration get latency =>
      Duration(milliseconds: 900 + _random.nextInt(700));
}
