import 'package:flutter/material.dart';

import '../models/task.dart';
import '../store/app_store.dart';
import '../ui/style.dart';
import 'create_task_sheet.dart';

/// ③ タスク詳細: A・B・C から選ぶ or AIと話して「最初の一歩」を決定（仕様 §2.2）
class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen(
      {super.key, required this.store, required this.taskId});

  final AppStore store;
  final String taskId;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();
  bool _aiTyping = false;
  bool _generating = false;
  int? _pickedIndex; // A/B/C タップ直後の「その場変化」用

  AppStore get store => widget.store;
  Task? get task => store.taskById(widget.taskId);

  @override
  void initState() {
    super.initState();
    _generateIfNeeded();
  }

  void _generateIfNeeded() {
    // 保存直後・編集後で提案が未生成なら自動生成（仕様 §2.2）
    final t = task;
    if (t != null && t.suggestions.isEmpty) {
      setState(() => _generating = true);
      store.ai.generateSuggestions(t).then((s) {
        if (!mounted) return;
        final t2 = task;
        if (t2 != null) {
          store.updateTask(t2, (x) => x.suggestions = s);
        }
        setState(() => _generating = false);
      });
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _pickStep(Task t, int index) {
    if (_pickedIndex != null) return;
    setState(() => _pickedIndex = index);
    // 選んだ行がその場で変化 → 一拍おいて決定表示へ（仕様 §2.2 v1.3）
    Future.delayed(const Duration(milliseconds: 550), () {
      if (!mounted) return;
      final t2 = task;
      if (t2 != null && index < t2.suggestions.length) {
        store.updateTask(t2, (x) => x.firstStep = x.suggestions[index]);
      }
      setState(() => _pickedIndex = null);
    });
  }

  void _sendChat() {
    final t = task;
    final text = _chatController.text.trim();
    if (t == null || text.isEmpty || _aiTyping) return;
    _chatController.clear();
    store.updateTask(t, (x) => x.chat.add(ChatMessage(role: 'user', text: text)));
    setState(() => _aiTyping = true);
    _scrollToBottom();
    store.ai.chat(t, text).then((result) {
      if (!mounted) return;
      final t2 = task;
      if (t2 != null) {
        // v1.3: チャットは入力支援に徹する — A・B・C はいじらない
        store.updateTask(t2, (x) {
          x.chat.add(ChatMessage(
              role: 'ai', text: result.reply, proposal: result.proposal));
        });
      }
      setState(() => _aiTyping = false);
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _edit() async {
    final t = task;
    if (t == null) return;
    final result = await showTaskSheet(context, store, edit: t);
    if (result != null && result.needsRegen && mounted) {
      _generateIfNeeded();
    }
  }

  Future<void> _delete() async {
    final t = task;
    if (t == null) return;
    final ok = await showConfirmDialog(
      context,
      title: 'タスクを削除',
      message: '「${t.title}」を削除します。',
      okLabel: '削除',
    );
    if (ok && mounted) {
      store.deleteTask(t.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ストアを購読して即時反映（v1.3 バグ修正: 戻るまでUIが更新されない問題）
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final t = task;
        if (t == null) {
          // 完了・削除済み
          return const Scaffold(body: SizedBox());
        }
        return Scaffold(
          backgroundColor: AdhtColors.bg,
          appBar: AppBar(
            backgroundColor: AdhtColors.bg,
            title: const Text('タスク',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            actions: [
              TextButton(onPressed: _edit, child: const Text('編集')),
              TextButton(
                onPressed: _delete,
                child:
                    const Text('削除', style: TextStyle(color: AdhtColors.red)),
              ),
            ],
          ),
          body: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(t.title,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    BrainBadge(t.brainType),
                    PriorityBadge(t.priority),
                    DeadlineBadge(t),
                  ],
                ),
              ),
              ..._stepSection(t),
              const SectionLabel('💬 AIと話して最初の一歩を決める'),
              _chatBox(t),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AdhtColors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  store.completeTask(t.id);
                  Navigator.pop(context);
                },
                child: const Text('✓ このタスクを完了する（リストから消えます）',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _stepSection(Task t) {
    if (_generating) {
      return [
        const SectionLabel('🤖 最初の一歩（AI提案）'),
        Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: AdhtColors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: AdhtColors.accent),
              ),
              SizedBox(height: 10),
              Text('AIが最初の一歩を考えています…',
                  style: TextStyle(fontSize: 13.5, color: AdhtColors.muted)),
            ],
          ),
        ),
      ];
    }
    if (t.firstStep != null && _pickedIndex == null) {
      return [
        const SectionLabel('👣 決定した最初の一歩'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AdhtColors.accentWeak,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AdhtColors.accent, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.firstStep!,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.6)),
              const SizedBox(height: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AdhtColors.accent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                ),
                onPressed: () => store.updateTask(t, (x) => x.firstStep = null),
                child: const Text('選び直す',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ];
    }
    return [
      const SectionLabel('🤖 最初の一歩（AI提案）'),
      Container(
        decoration: BoxDecoration(
          color: AdhtColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final (i, s) in t.suggestions.take(3).indexed) ...[
              if (i > 0)
                const Divider(
                    height: 1, thickness: 1, color: AdhtColors.separator),
              _suggestionRow(t, i, s),
            ],
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Center(
          child: Text('タップで決定。しっくりこなければ下のAIと相談',
              style: TextStyle(fontSize: 11.5, color: AdhtColors.muted)),
        ),
      ),
    ];
  }

  Widget _suggestionRow(Task t, int i, String s) {
    final picked = _pickedIndex == i;
    final dimmed = _pickedIndex != null && !picked;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      opacity: dimmed ? 0.25 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: picked ? AdhtColors.accentWeak : Colors.transparent,
        child: InkWell(
          onTap: () => _pickStep(t, i),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: picked ? AdhtColors.accent : AdhtColors.accentWeak,
                    shape: BoxShape.circle,
                  ),
                  child: Text(picked ? '✓' : 'ABC'[i],
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: picked ? Colors.white : AdhtColors.accent)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child:
                      Text(s, style: const TextStyle(fontSize: 13.5, height: 1.6)),
                ),
                const SizedBox(width: 8),
                AdhtBadge(picked ? '👣 決定！' : 'これ',
                    background:
                        picked ? AdhtColors.green : AdhtColors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chatBox(Task t) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AdhtColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          if (t.chat.isEmpty && !_aiTyping)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Text(
                '自分の言葉で書けば、それがそのまま最初の一歩になります\n（例:「レシートを机に出すだけ」）',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, height: 1.7, color: AdhtColors.muted),
              ),
            ),
          for (final (i, m) in t.chat.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            _bubble(t, m),
          ],
          if (_aiTyping) ...[
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: TypingBubble(),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: AdhtColors.separator),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  enabled: !_aiTyping,
                  onSubmitted: (_) => _sendChat(),
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'やれそうなことを自分の言葉で…',
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF0F0F5),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 36,
                height: 36,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AdhtColors.accent,
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  onPressed: _aiTyping ? null : _sendChat,
                  child: const Text('↑',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bubble(Task t, ChatMessage m) {
    final isUser = m.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isUser ? AdhtColors.accent : const Color(0xFFF0F0F5),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 5),
            bottomRight: Radius.circular(isUser ? 5 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.text,
                style: TextStyle(
                    fontSize: 13.5,
                    height: 1.55,
                    color: isUser ? Colors.white : AdhtColors.text)),
            if (m.proposal != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AdhtColors.accent, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.proposal!,
                        style: const TextStyle(fontSize: 13, height: 1.55)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AdhtColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          minimumSize: Size.zero,
                        ),
                        onPressed: () => store.updateTask(
                            t, (x) => x.firstStep = m.proposal),
                        child: const Text('👣 これを最初の一歩にする',
                            style: TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 「…」タイピングインジケーター（相談タブと共用）
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Opacity(
                  opacity: 0.3 +
                      0.7 *
                          (1 -
                                  ((_controller.value - i * 0.2) % 1.0 - 0.3)
                                          .abs() /
                                      0.7)
                              .clamp(0.0, 1.0),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFB0B0B8),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
