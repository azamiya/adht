import 'package:flutter/material.dart';

import '../models/task.dart';
import '../store/app_store.dart';
import '../ui/style.dart';
import 'task_detail_screen.dart';

enum BrainFilter { all, rightBrain, leftBrain }

/// ① タスク一覧。「すべて」は左＝左脳/右＝右脳の縦2分割（仕様 §3 ①）
class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  BrainFilter _filter = BrainFilter.all;

  AppStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text('タスク',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _SegmentedFilter(
              value: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (store.tasks.isEmpty) {
      return const Center(
        child: Text(
          '🎉\nタスクゼロ！\n「＋」から追加すると、AIが\n着手の入口をA・B・Cの3つ提案します',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.8, color: AdhtColors.muted),
        ),
      );
    }
    if (_filter == BrainFilter.all) return _splitColumns();

    final brain = _filter == BrainFilter.rightBrain
        ? BrainType.rightBrain
        : BrainType.leftBrain;
    final tasks = store.byBrain(brain);
    if (tasks.isEmpty) {
      return const Center(
        child: Text('🎉 このタイプのタスクはゼロ！',
            style: TextStyle(fontSize: 14, color: AdhtColors.muted)),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        for (final t in tasks) ...[
          _TaskCard(store: store, task: t, compact: false),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  /// 「すべて」= 画面縦2分割。左半分＝左脳（青）/ 右半分＝右脳（オレンジ）
  Widget _splitColumns() {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // 画面いっぱいまで背景を伸ばす
          minHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _BrainColumn(
                  store: store,
                  brain: BrainType.leftBrain,
                  background: AdhtColors.leftColumnBg,
                  emptyText: '論理・事務系は\nゼロ 🎉',
                ),
              ),
              Container(width: 1.5, color: Colors.white),
              Expanded(
                child: _BrainColumn(
                  store: store,
                  brain: BrainType.rightBrain,
                  background: AdhtColors.rightColumnBg,
                  emptyText: '創造・直感系は\nゼロ 🎉',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentedFilter extends StatelessWidget {
  const _SegmentedFilter({required this.value, required this.onChanged});

  final BrainFilter value;
  final ValueChanged<BrainFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(BrainFilter f, String label) {
      final active = value == f;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(f),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: active
                  ? [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 4,
                          offset: const Offset(0, 1)),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFE3E3E8),
        borderRadius: BorderRadius.circular(10),
      ),
      // UIルール: 左＝左脳、右＝右脳（仕様 §2.3）
      child: Row(
        children: [
          seg(BrainFilter.all, 'すべて'),
          const SizedBox(width: 2),
          seg(BrainFilter.leftBrain, '🧮 左脳'),
          const SizedBox(width: 2),
          seg(BrainFilter.rightBrain, '🎨 右脳'),
        ],
      ),
    );
  }
}

class _BrainColumn extends StatelessWidget {
  const _BrainColumn({
    required this.store,
    required this.brain,
    required this.background,
    required this.emptyText,
  });

  final AppStore store;
  final BrainType brain;
  final Color background;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final tasks = store.byBrain(brain);
    return Container(
      color: background,
      padding: const EdgeInsets.fromLTRB(9, 10, 9, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AdhtColors.brain(brain),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12), blurRadius: 8),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(brain.label,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${tasks.length}',
                      style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.6,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (tasks.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9), width: 1.5),
              ),
              child: Text(emptyText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11.5, height: 1.7, color: AdhtColors.muted)),
            )
          else
            for (final t in tasks) ...[
              _TaskCard(store: store, task: t, compact: true),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard(
      {required this.store, required this.task, required this.compact});

  final AppStore store;
  final Task task;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final check = GestureDetector(
      onTap: () => store.completeTask(task.id),
      child: Container(
        width: compact ? 22 : 26,
        height: compact ? 22 : 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFC7C7CC), width: 2),
        ),
      ),
    );

    final badges = Wrap(
      spacing: compact ? 4 : 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ProgressBattery(task.progress),
        if (!compact) BrainBadge(task.brainType),
        PriorityBadge(task.priority),
        DeadlineBadge(task),
      ],
    );

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TaskDetailScreen(store: store, taskId: task.id)),
      ),
      child: Container(
        padding: EdgeInsets.all(compact ? 11 : 13),
        decoration: BoxDecoration(
          color: AdhtColors.card,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 3),
          ],
        ),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(task.title,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                height: 1.35)),
                      ),
                      const SizedBox(width: 6),
                      check,
                    ],
                  ),
                  const SizedBox(height: 8),
                  badges,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  check,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(task.title,
                            style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                height: 1.35)),
                        const SizedBox(height: 5),
                        badges,
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
