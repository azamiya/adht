import 'package:flutter/material.dart';

import '../models/task.dart';
import '../store/app_store.dart';
import '../ui/style.dart';
import 'task_detail_screen.dart' show TypingBubble;

/// ⑤ AIに相談: アプリ横断のAIチャット（仕様 §2.6 v1.3）
class ConsultScreen extends StatefulWidget {
  const ConsultScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ConsultScreen> createState() => _ConsultScreenState();
}

class _ConsultScreenState extends State<ConsultScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  AppStore get store => widget.store;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || store.consultTyping) return;
    _controller.clear();
    store.sendConsult(text);
    _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    final consult = store.consult;
    if (store.consultTyping || consult.isNotEmpty) _scrollToBottom();
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text('AIに相談',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              children: [
                if (consult.isEmpty && !store.consultTyping)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'タスクのことも、気分のことも、なんでもどうぞ\n（例:「今日明日でやらないといけないタスクは？」\n「だるくてやる気がしない」）',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, height: 1.8, color: AdhtColors.muted),
                    ),
                  ),
                for (final (i, m) in consult.indexed) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _bubble(m),
                ],
                if (store.consultTyping) ...[
                  const SizedBox(height: 8),
                  const Align(
                      alignment: Alignment.centerLeft, child: TypingBubble()),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: AdhtColors.bg,
              border:
                  Border(top: BorderSide(color: AdhtColors.separator, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !store.consultTyping,
                    onSubmitted: (_) => _send(),
                    style: const TextStyle(fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'なんでも聞いてOK…',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 38,
                  height: 38,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AdhtColors.accent,
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                    ),
                    onPressed: store.consultTyping ? null : _send,
                    child: const Text('↑',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessage m) {
    final isUser = m.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isUser ? AdhtColors.accent : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 5),
            bottomRight: Radius.circular(isUser ? 5 : 16),
          ),
        ),
        child: Text(m.text,
            style: TextStyle(
                fontSize: 13.5,
                height: 1.6,
                color: isUser ? Colors.white : AdhtColors.text)),
      ),
    );
  }
}
