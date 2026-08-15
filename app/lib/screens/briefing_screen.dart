import 'package:flutter/material.dart';

import '../models/task.dart';
import '../store/app_store.dart';
import '../ui/style.dart';
import 'task_detail_screen.dart';

/// ④ ブリーフィング「今日はこの3つだけ」（仕様 §2.5）
class BriefingScreen extends StatelessWidget {
  const BriefingScreen({super.key, required this.store});

  final AppStore store;

  static const _weekdays = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  Widget build(BuildContext context) {
    final tasks = store.briefingPick();
    final now = DateTime.now();
    final dateStr = '${now.month}月${now.day}日(${_weekdays[now.weekday - 1]})';

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 4, 12),
            child: Text('今日のブリーフィング',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
          ),
          _BriefingMessage(
              dateStr: dateStr,
              text: store.briefingText() ?? '（今日のコメントを考え中…）',
              onRefresh: store.refreshBriefing),
          const SizedBox(height: 14),
          for (final task in tasks) ...[
            _BriefingCard(store: store, task: task),
            const SizedBox(height: 12),
          ],
          if (tasks.isNotEmpty)
            const Center(
              child: Text(
                '今日はこれだけでOK。全部のリストは「タスク」タブに。',
                style: TextStyle(fontSize: 12, color: AdhtColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _BriefingMessage extends StatelessWidget {
  const _BriefingMessage(
      {required this.dateStr, required this.text, required this.onRefresh});

  final String dateStr;
  final String text;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AdhtColors.accent, Color(0xFF7D7BF0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AdhtColors.accent.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('$dateStr　ADHTからのコメント',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.8))),
              ),
              // ブリーフィング更新（仕様 §2.5 v1.3）
              GestureDetector(
                onTap: onRefresh,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.refresh,
                      size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 14.5, height: 1.65, color: Colors.white)),
        ],
      ),
    );
  }
}

class _BriefingCard extends StatelessWidget {
  const _BriefingCard({required this.store, required this.task});

  final AppStore store;
  final Task task;

  @override
  Widget build(BuildContext context) {
    // カード全体のタップでタスク詳細へ（ボタン類は各自のonPressedが優先される）
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TaskDetailScreen(store: store, taskId: task.id)),
      ),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdhtColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 3),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.title,
              style:
                  const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            decoration: BoxDecoration(
              color: AdhtColors.accentWeak,
              borderRadius: BorderRadius.circular(8),
              border: const Border(
                  left: BorderSide(color: AdhtColors.accent, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.firstStep != null ? '👣 決定した最初の一歩' : '最初の一歩（AI提案）',
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AdhtColors.accent),
                ),
                const SizedBox(height: 2),
                Text(task.displayFirstStep,
                    style: const TextStyle(fontSize: 13.5, height: 1.55)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ProgressBattery(task.progress),
              PriorityBadge(task.priority),
              AdhtBadge(task.priority.timeHint,
                  background: const Color(0xFFF0F0F5),
                  foreground: AdhtColors.muted),
              DeadlineBadge(task),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AdhtColors.green,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  onPressed: () => store.completeTask(task.id),
                  child: const Text('✓ 完了',
                      style:
                          TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF0F0F5),
                    foregroundColor: AdhtColors.text,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TaskDetailScreen(store: store, taskId: task.id),
                    ),
                  ),
                  child: const Text('提案を見る',
                      style:
                          TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}
