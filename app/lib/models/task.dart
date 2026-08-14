import 'dart:math';

/// 脳タイプ（仕様 §2.1）
enum BrainType {
  rightBrain, // 右脳: 創造・直感系
  leftBrain; // 左脳: 論理・事務系

  String get label => this == BrainType.rightBrain ? '🎨 右脳' : '🧮 左脳';

  static BrainType fromJson(Object? v) =>
      v == 'rightBrain' ? BrainType.rightBrain : BrainType.leftBrain;

  String toJson() => name;
}

/// Priority 4段階（仕様 §2.1）
enum Priority {
  gekiomo(label: '🔥 激重', weight: 4, timeHint: 'まず5分だけ'),
  omoi(label: '重い', weight: 3, timeHint: '目安30分'),
  futsuu(label: '普通', weight: 2, timeHint: '目安15分'),
  karui(label: '軽い', weight: 1, timeHint: '目安5分');

  const Priority({
    required this.label,
    required this.weight,
    required this.timeHint,
  });

  final String label;
  final int weight;
  final String timeHint;

  static Priority fromJson(Object? v) => Priority.values.firstWhere(
        (p) => p.name == v,
        orElse: () => Priority.futsuu,
      );

  String toJson() => name;
}

/// AIとの会話 1 メッセージ（仕様 §2.2）
class ChatMessage {
  ChatMessage({required this.role, required this.text, this.proposal});

  final String role; // "user" | "ai"
  final String text;
  final String? proposal; // AI返信に添える「最初の一歩」候補

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] == 'ai' ? 'ai' : 'user',
        text: (json['text'] ?? '') as String,
        proposal: json['proposal'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
        if (proposal != null) 'proposal': proposal,
      };
}

String _generateId() {
  final rand = Random();
  final hex = List.generate(8, (_) => rand.nextInt(16).toRadixString(16));
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-${hex.join()}';
}

/// タスク（仕様 §4 データモデル）
class Task {
  Task({
    String? id,
    required this.title,
    required this.brainType,
    required this.priority,
    required this.deadline,
    List<ChatMessage>? chat,
    List<String>? suggestions,
    this.firstStep,
    DateTime? createdAt,
  })  : id = id ?? _generateId(),
        chat = chat ?? [],
        suggestions = suggestions ?? [],
        createdAt = createdAt ?? DateTime.now();

  final String id;
  String title;
  BrainType brainType;
  Priority priority;
  DateTime deadline; // 日付のみ意味を持つ
  List<ChatMessage> chat;
  List<String> suggestions; // A・B・C の3案
  String? firstStep; // 決定した「最初の一歩」
  final DateTime createdAt;

  /// 期限まで残り日数（マイナス = 超過）
  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(deadline.year, deadline.month, deadline.day);
    return due.difference(today).inDays;
  }

  /// ブリーフィングの優先度スコア（期限の近さ × Priority）
  int get briefingScore => priority.weight * 2 - daysLeft;

  /// 表示する「最初の一歩」（決定済み優先、なければA案）
  String get displayFirstStep =>
      firstStep ??
      (suggestions.isNotEmpty
          ? suggestions.first
          : 'まず5分だけタイマーをセットして着手');

  static String _dateToJson(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// インポート時のマイグレーション込みで復元（仕様 §2.4:
  /// 欠けたフィールドはデフォルト値で補完する）
  factory Task.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(Object? v, DateTime fallback) {
      if (v is String) {
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return parsed;
      }
      return fallback;
    }

    return Task(
      id: json['id'] is String ? json['id'] as String : null,
      title: ((json['title'] ?? '') as String).trim(),
      brainType: BrainType.fromJson(json['brainType']),
      priority: Priority.fromJson(json['priority']),
      deadline: parseDate(
          json['deadline'], DateTime.now().add(const Duration(days: 1))),
      chat: (json['chat'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(ChatMessage.fromJson)
              .toList() ??
          [],
      suggestions:
          (json['suggestions'] as List?)?.whereType<String>().take(3).toList() ??
              [],
      firstStep: json['firstStep'] as String?,
      createdAt: parseDate(json['createdAt'], DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'brainType': brainType.toJson(),
        'priority': priority.toJson(),
        'deadline': _dateToJson(deadline),
        'chat': chat.map((m) => m.toJson()).toList(),
        'suggestions': suggestions,
        'firstStep': firstStep,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// 通知の口調（仕様 §2.5: ハイブリッド）
enum Tone {
  gentle,
  tsukkomi;

  static Tone fromJson(Object? v) =>
      v == 'tsukkomi' ? Tone.tsukkomi : Tone.gentle;

  String toJson() => name;
}

/// アプリ設定（仕様 §4）
class AppSettings {
  AppSettings({this.tone = Tone.gentle, this.briefingHour = 8});

  Tone tone;
  int briefingHour;

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        tone: Tone.fromJson(json['tone']),
        briefingHour: (json['briefingHour'] as num?)?.toInt() ?? 8,
      );

  Map<String, dynamic> toJson() =>
      {'tone': tone.toJson(), 'briefingHour': briefingHour};
}
