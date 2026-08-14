import 'package:flutter/material.dart';

import '../models/task.dart';
import '../store/app_store.dart';
import '../ui/style.dart';

/// ② タスク作成シート（仕様 §2.1: 必須4項目）
/// 保存すると Task を返す。呼び出し側で詳細画面へ遷移して AI 提案を自動生成する。
Future<Task?> showCreateTaskSheet(BuildContext context, AppStore store) {
  return showModalBottomSheet<Task>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AdhtColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _CreateTaskSheet(store: store),
  );
}

class _CreateTaskSheet extends StatefulWidget {
  const _CreateTaskSheet({required this.store});

  final AppStore store;

  @override
  State<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<_CreateTaskSheet> {
  final _titleController = TextEditingController();
  BrainType? _brainType;
  Priority? _priority;
  DateTime _deadline = DateTime.now().add(const Duration(days: 1));

  bool get _valid =>
      _titleController.text.trim().isNotEmpty &&
      _brainType != null &&
      _priority != null;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _save() {
    final task = widget.store.addTask(
      title: _titleController.text.trim(),
      brainType: _brainType!,
      priority: _priority!,
      deadline: _deadline,
    );
    Navigator.pop(context, task);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC7C7CC),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                  const Text('新しいタスク',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  TextButton(
                    onPressed: _valid ? _save : null,
                    child: const Text('保存',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _titleController,
                autofocus: true,
                maxLength: 80,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: '何をやる？（例: HDMIキャプチャの調査）',
                  counterText: '',
                  filled: true,
                  fillColor: AdhtColors.card,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              _formLabel('脳タイプ'),
              Row(
                children: [
                  _choiceChip(
                    label: '🎨 右脳（創造・直感）',
                    selected: _brainType == BrainType.rightBrain,
                    color: AdhtColors.rightBrain,
                    onTap: () =>
                        setState(() => _brainType = BrainType.rightBrain),
                  ),
                  const SizedBox(width: 8),
                  _choiceChip(
                    label: '🧮 左脳（論理・事務）',
                    selected: _brainType == BrainType.leftBrain,
                    color: AdhtColors.leftBrain,
                    onTap: () =>
                        setState(() => _brainType = BrainType.leftBrain),
                  ),
                ],
              ),
              _formLabel('Priority'),
              Row(
                children: [
                  for (final (i, p) in Priority.values.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _choiceChip(
                      label: p.label,
                      selected: _priority == p,
                      color: AdhtColors.priority(p),
                      onTap: () => setState(() => _priority = p),
                    ),
                  ],
                ],
              ),
              _formLabel('期限'),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AdhtColors.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_deadline.year}/${_deadline.month}/${_deadline.day}',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  '保存すると、AIが着手の入口を A・B・C の3つ提案します',
                  style: TextStyle(fontSize: 12, color: AdhtColors.muted),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Row(
        children: [
          Text(text,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AdhtColors.muted)),
          const SizedBox(width: 4),
          const Text('必須',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AdhtColors.red)),
        ],
      ),
    );
  }

  Widget _choiceChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.1) : AdhtColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? color : AdhtColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
