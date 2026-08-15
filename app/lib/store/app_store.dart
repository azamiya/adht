import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/ai_client.dart';
import '../ai/gemini_ai.dart';
import '../ai/mock_ai.dart';
import '../models/task.dart';
import '../secrets.dart';

/// インポート結果
sealed class ImportResult {
  const ImportResult();
}

class ImportSuccess extends ImportResult {
  const ImportSuccess(this.count);
  final int count;
}

class ImportError extends ImportResult {
  const ImportError(this.message);
  final String message;
}

/// アプリ全体の状態と永続化（ローカルのみ、仕様 §5）。
/// 保存形式はエクスポートと同じ JSON なので、ストレージ移行にも強い。
class AppStore extends ChangeNotifier {
  AppStore(this._prefs, this.ai);

  static const _tasksKey = 'adht-tasks';
  static const _settingsKey = 'adht-settings';
  static const _consultKey = 'adht-consult';

  final SharedPreferences _prefs;
  final AiClient ai;

  List<Task> tasks = [];
  AppSettings settings = AppSettings();

  /// AIに相談の会話履歴（仕様 §2.6）
  List<ChatMessage> consult = [];
  bool consultTyping = false;

  /// その日のブリーフィング文面（画面出入りで変わりすぎないようキャッシュ）
  String? _briefingText;
  bool _briefingLoading = false;

  static Future<AppStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    // キー未設定ならモックで動く（secrets.example.dart 参照）
    final AiClient ai = geminiApiKey.isNotEmpty
        ? GeminiAi(apiKey: geminiApiKey)
        : MockAi();
    final store = AppStore(prefs, ai);
    try {
      final rawTasks = prefs.getString(_tasksKey);
      if (rawTasks != null) {
        store.tasks = (jsonDecode(rawTasks) as List)
            .whereType<Map<String, dynamic>>()
            .map(Task.fromJson)
            .toList();
      } else {
        store.tasks = store._seedTasks();
        store._persist();
      }
      final rawSettings = prefs.getString(_settingsKey);
      if (rawSettings != null) {
        store.settings =
            AppSettings.fromJson(jsonDecode(rawSettings) as Map<String, dynamic>);
      }
      final rawConsult = prefs.getString(_consultKey);
      if (rawConsult != null) {
        store.consult = (jsonDecode(rawConsult) as List)
            .whereType<Map<String, dynamic>>()
            .map(ChatMessage.fromJson)
            .toList();
      }
    } catch (_) {
      // 破損時はシードに戻す（個人利用・消えてもよい前提、仕様 §7）
      store.tasks = store._seedTasks();
      store._persist();
    }
    // 提案が未生成のタスクを裏で埋める（シード直後・過去の生成失敗のリトライ）
    store._fillMissingSuggestions();
    return store;
  }

  void _fillMissingSuggestions() {
    for (final t in tasks.where((t) => t.suggestions.isEmpty)) {
      ai.generateSuggestions(t).then((s) {
        if (tasks.contains(t)) updateTask(t, (x) => x.suggestions = s);
      }).catchError((_) {});
    }
  }

  List<Task> _seedTasks() {
    final now = DateTime.now();
    Task seed(String title, BrainType b, Priority p, int days) {
      return Task(
        title: title,
        brainType: b,
        priority: p,
        deadline: now.add(Duration(days: days)),
      );
    }

    return [
      seed('HDMIキャプチャの調査を行う', BrainType.leftBrain, Priority.omoi, 2),
      seed('ブログのアイキャッチ画像を作る', BrainType.rightBrain, Priority.futsuu, 1),
      seed('経費精算をやる', BrainType.leftBrain, Priority.gekiomo, 0),
      seed('新アプリのアイデアをラフに描く', BrainType.rightBrain, Priority.karui, 4),
    ];
  }

  void _persist() {
    _prefs.setString(
        _tasksKey, jsonEncode(tasks.map((t) => t.toJson()).toList()));
    _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
    _prefs.setString(
        _consultKey, jsonEncode(consult.map((m) => m.toJson()).toList()));
  }

  void _mutate(void Function() fn) {
    fn();
    _persist();
    notifyListeners();
  }

  /* ---------- CRUD ---------- */

  Task addTask({
    required String title,
    required BrainType brainType,
    required Priority priority,
    required DateTime deadline,
  }) {
    final task = Task(
      title: title,
      brainType: brainType,
      priority: priority,
      deadline: deadline,
    );
    _mutate(() => tasks.add(task));
    return task;
  }

  Task? taskById(String id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 完了 = 削除（仕様 §2.3: 履歴は残さない）
  void completeTask(String id) => _mutate(() {
        tasks.removeWhere((t) => t.id == id);
      });

  void deleteTask(String id) => completeTask(id);

  void updateTask(Task task, void Function(Task) fn) => _mutate(() => fn(task));

  /* ---------- 並び・抽出 ---------- */

  /// 軽い順（軽い→激重）。同じ重さなら期限が近い順。
  /// 一番軽いものから始めるとエンジンがかかる、という着手優先の並び（v1.3）。
  List<Task> sorted(Iterable<Task> src) {
    final list = [...src];
    list.sort((a, b) {
      final byWeight = a.priority.weight.compareTo(b.priority.weight);
      if (byWeight != 0) return byWeight;
      return a.deadline.compareTo(b.deadline);
    });
    return list;
  }

  List<Task> byBrain(BrainType brain) =>
      sorted(tasks.where((t) => t.brainType == brain));

  /// ブリーフィング「今日はこの3つだけ」（仕様 §2.5）
  /// 選定は緊急度スコア、表示は軽い順（v1.3）
  List<Task> briefingPick() {
    final list = [...tasks];
    list.sort((a, b) => b.briefingScore.compareTo(a.briefingScore));
    return sorted(list.take(3).toList());
  }

  /// ブリーフィング文面。未生成なら null を返しつつ裏で生成を開始する。
  String? briefingText() {
    final picked = briefingPick();
    if (picked.isEmpty) return '今日のタスクはありません。ゆっくりどうぞ ☕';
    if (_briefingText != null) return _briefingText;
    if (!_briefingLoading) {
      _briefingLoading = true;
      ai.briefingMessage(picked, settings.tone).then((msg) {
        _briefingText = msg;
        _briefingLoading = false;
        notifyListeners();
      }).catchError((_) {
        _briefingLoading = false;
      });
    }
    return null;
  }

  /// ブリーフィングを作り直す（↻ 更新ボタン、仕様 §2.5 v1.3）
  void refreshBriefing() {
    _briefingText = null;
    _briefingLoading = false;
    notifyListeners(); // briefingText() が再生成を開始する
  }

  /* ---------- AIに相談（仕様 §2.6） ---------- */

  Future<void> sendConsult(String text) async {
    consult.add(ChatMessage(role: 'user', text: text));
    consultTyping = true;
    _persist();
    notifyListeners();
    try {
      final reply = await ai.consult(sorted(tasks), settings.tone, text);
      consult.add(ChatMessage(role: 'ai', text: reply));
    } finally {
      consultTyping = false;
      _persist();
      notifyListeners();
    }
  }

  /* ---------- タスク編集（仕様 §2.3 v1.3） ---------- */

  /// タイトル・脳タイプ・Priority・期限を更新。
  /// タイトルまたは脳タイプが変わったら A・B・C を再生成し、決定もリセットする。
  /// 戻り値: 提案の再生成が必要になったかどうか。
  bool editTask(
    Task task, {
    required String title,
    required BrainType brainType,
    required Priority priority,
    required DateTime deadline,
  }) {
    final needsRegen = task.title != title || task.brainType != brainType;
    _mutate(() {
      task.title = title;
      task.brainType = brainType;
      task.priority = priority;
      task.deadline = deadline;
      if (needsRegen) {
        task.firstStep = null;
        task.suggestions = [];
      }
    });
    return needsRegen;
  }

  /* ---------- 設定 ---------- */

  void setTone(Tone tone) => _mutate(() {
        settings.tone = tone;
        _briefingText = null; // 口調変更は次の文面から反映
      });

  void setBriefingHour(int hour) => _mutate(() => settings.briefingHour = hour);

  void resetToSeed() => _mutate(() {
        tasks = _seedTasks();
        _briefingText = null;
      });

  /* ---------- インポート / エクスポート（仕様 §2.4） ---------- */

  /// エクスポートJSONの形式バージョン（仕様 §2.4）。
  /// v2: progress（0-100%）追加。v1（〜アプリv1.3.0）のインポートは可（progress=0補完）。
  static const exportFormatVersion = 2;

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
        'format': 'adht-tasks',
        'version': exportFormatVersion,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
      });

  /// JSON を検証してタスク数を返す（まだ取り込まない）。エラーならメッセージ。
  ({List<Task>? tasks, String? error}) parseImport(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return (tasks: null, error: 'インポートするJSONを貼り付けてください');
    }
    Object? parsed;
    try {
      parsed = jsonDecode(trimmed);
    } catch (_) {
      return (
        tasks: null,
        error: 'JSONとして読めませんでした。コピペが途中で切れていないか確認してください'
      );
    }
    List<dynamic>? rawTasks;
    if (parsed is List) {
      rawTasks = parsed;
    } else if (parsed is Map<String, dynamic>) {
      final format = parsed['format'];
      if (format != null && format != 'adht-tasks') {
        return (tasks: null, error: '知らない形式です（format: $format）。何も変更していません');
      }
      // 互換ルール（仕様 §2.4）: 旧→新は常に可。ダウングレードインポートは非対応。
      final version = parsed['version'];
      if (version is num && version > exportFormatVersion) {
        return (
          tasks: null,
          error:
              'このJSONはより新しい形式（version ${version.toInt()}）です。アプリを更新してからインポートしてください'
        );
      }
      rawTasks = parsed['tasks'] as List?;
    }
    if (rawTasks == null) {
      return (tasks: null, error: 'tasks の配列が見つかりません。何も変更していません');
    }
    final imported = <Task>[];
    for (final r in rawTasks) {
      if (r is! Map<String, dynamic> ||
          (r['title'] is! String) ||
          (r['title'] as String).trim().isEmpty) {
        return (tasks: null, error: 'title のないタスクが含まれています。何も変更していません');
      }
      imported.add(Task.fromJson(r));
    }
    return (tasks: imported, error: null);
  }

  /// 全置き換えで取り込む
  ImportResult importTasks(List<Task> imported) {
    _mutate(() {
      tasks = imported;
      _briefingText = null;
    });
    return ImportSuccess(imported.length);
  }
}
