import 'package:flutter/material.dart';

import '../models/task.dart';

/// デザイントークン（プロトタイプ prototype.css と対応）
abstract final class AdhtColors {
  static const accent = Color(0xFF5E5CE6);
  static const accentWeak = Color(0xFFEEEEFC);
  static const bg = Color(0xFFF2F2F7);
  static const card = Colors.white;
  static const text = Color(0xFF1C1C1E);
  static const muted = Color(0xFF8E8E93);
  static const separator = Color(0xFFE5E5EA);
  static const green = Color(0xFF34C759);
  static const red = Color(0xFFFF3B30);

  static const rightBrain = Color(0xFFFF9F0A);
  static const leftBrain = Color(0xFF32ADE6);

  static const leftColumnBg = Color(0xFFD9EDF9); // 左脳カラム背景
  static const rightColumnBg = Color(0xFFFBEBD1); // 右脳カラム背景

  static Color brain(BrainType b) =>
      b == BrainType.rightBrain ? rightBrain : leftBrain;

  static Color priority(Priority p) => switch (p) {
        Priority.gekiomo => red,
        Priority.omoi => rightBrain,
        Priority.futsuu => leftBrain,
        Priority.karui => green,
      };
}

class AdhtBadge extends StatelessWidget {
  const AdhtBadge(this.label,
      {super.key, required this.background, this.foreground = Colors.white});

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11.5, fontWeight: FontWeight.w600, color: foreground),
      ),
    );
  }
}

class BrainBadge extends StatelessWidget {
  const BrainBadge(this.brain, {super.key});
  final BrainType brain;

  @override
  Widget build(BuildContext context) =>
      AdhtBadge(brain.label, background: AdhtColors.brain(brain));
}

class PriorityBadge extends StatelessWidget {
  const PriorityBadge(this.priority, {super.key});
  final Priority priority;

  @override
  Widget build(BuildContext context) =>
      AdhtBadge(priority.label, background: AdhtColors.priority(priority));
}

class DeadlineBadge extends StatelessWidget {
  const DeadlineBadge(this.task, {super.key});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final d = task.daysLeft;
    if (d < 0) {
      return AdhtBadge('期限を${-d}日超過',
          background: const Color(0xFFFFEBEE), foreground: AdhtColors.red);
    }
    if (d == 0) {
      return AdhtBadge('今日が期限',
          background: const Color(0xFFFFF3E0),
          foreground: const Color(0xFFE65100));
    }
    return AdhtBadge('あと$d日',
        background: const Color(0xFFF0F0F5), foreground: AdhtColors.muted);
  }
}

/// 進捗度の充電池マーク（表示専用、仕様 §2.3 v1.4）
/// 4目盛り: 25%=赤 / 50%=オレンジ / 75%以上=緑、0%は空
class ProgressBattery extends StatelessWidget {
  const ProgressBattery(this.progress, {super.key});

  final int progress; // 0/25/50/75/100

  Color get _color {
    if (progress >= 75) return AdhtColors.green;
    if (progress >= 50) return AdhtColors.rightBrain; // オレンジ
    return AdhtColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final bars = progress ~/ 25; // 0〜4
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFA5A5AD), width: 1.5),
            borderRadius: BorderRadius.circular(4.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Container(
                  width: 4.5,
                  height: 10,
                  decoration: BoxDecoration(
                    color: i < bars ? _color : const Color(0xFFE4E4E9),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ],
            ],
          ),
        ),
        // 電池の端子
        Container(
          width: 3,
          height: 7,
          decoration: const BoxDecoration(
            color: Color(0xFFA5A5AD),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(2),
              bottomRight: Radius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AdhtColors.muted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// iOS風の確認ダイアログ（プロトタイプの ios-dialog と対応）
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String okLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFFFAFAFC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Text(message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, height: 1.6)),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(okLabel,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return result ?? false;
}
