import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';
import '../store/app_store.dart';
import '../ui/style.dart';

/// ⑤ 設定: 口調・ブリーフィング時刻・JSONインポート/エクスポート（仕様 §2.4）
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ioController = TextEditingController();
  String _ioStatus = '';
  bool _ioError = false;

  AppStore get store => widget.store;

  @override
  void dispose() {
    _ioController.dispose();
    super.dispose();
  }

  void _setStatus(String msg, {bool error = false}) {
    setState(() {
      _ioStatus = msg;
      _ioError = error;
    });
  }

  Future<void> _export() async {
    final json = store.exportJson();
    _ioController.text = json;
    await Clipboard.setData(ClipboardData(text: json));
    _setStatus('✓ ${store.tasks.length}件をエクスポートし、クリップボードにコピーしました');
  }

  Future<void> _import() async {
    final result = store.parseImport(_ioController.text);
    if (result.error != null) {
      _setStatus(result.error!, error: true);
      return;
    }
    final imported = result.tasks!;
    final ok = await showConfirmDialog(
      context,
      title: 'タスクをインポート',
      message:
          '${imported.length}件のタスクを取り込みます。\n既存の${store.tasks.length}件は置き換えられます。',
      okLabel: 'インポート',
    );
    if (!ok) {
      _setStatus('インポートをキャンセルしました');
      return;
    }
    store.importTasks(imported);
    _setStatus('✓ ${imported.length}件のタスクをインポートしました');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 4, 12),
            child: Text('設定',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
          ),
          _group(
            label: '通知の口調',
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  _toneChip(Tone.gentle, 'やさしめ'),
                  const SizedBox(width: 8),
                  _toneChip(Tone.tsukkomi, 'ツッコミ多め'),
                ],
              ),
              const SizedBox(height: 8),
              const Text('どちらでも、恥をかかせる言い方は絶対にしません（仕様 §2.5）',
                  style: TextStyle(
                      fontSize: 12, height: 1.6, color: AdhtColors.muted)),
            ],
          ),
          _group(
            label: '朝ブリーフィングの時刻',
            children: [
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime:
                        TimeOfDay(hour: store.settings.briefingHour, minute: 0),
                  );
                  if (picked != null) {
                    store.setBriefingHour(picked.hour);
                    setState(() {});
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${store.settings.briefingHour.toString().padLeft(2, '0')}:00',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('通知は朝1回＋期限当日のみ。しつこい通知はしません',
                  style: TextStyle(
                      fontSize: 12, height: 1.6, color: AdhtColors.muted)),
            ],
          ),
          _group(
            label: 'タスクのエクスポート / インポート',
            children: [
              const SizedBox(height: 4),
              const Text('バージョンアップでデータ形式が変わっても、JSONコピペで引っ越せます',
                  style: TextStyle(
                      fontSize: 12, height: 1.6, color: AdhtColors.muted)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AdhtColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: _export,
                      child: const Text('📤 エクスポート',
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF0F0F5),
                        foregroundColor: AdhtColors.text,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: _import,
                      child: const Text('📥 インポート',
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _ioController,
                maxLines: 6,
                style: const TextStyle(
                    fontSize: 11, height: 1.5, fontFamily: 'Menlo'),
                decoration: InputDecoration(
                  hintText:
                      'エクスポート: ここにJSONが出ます（クリップボードにも自動コピー）\nインポート: ここにJSONを貼り付けて「インポート」を押す',
                  hintStyle:
                      const TextStyle(fontSize: 11, height: 1.5),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFC),
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AdhtColors.separator),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AdhtColors.separator),
                  ),
                ),
              ),
              if (_ioStatus.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_ioStatus,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            _ioError ? AdhtColors.red : AdhtColors.green)),
              ],
            ],
          ),
          _group(
            label: 'データ',
            children: [
              const SizedBox(height: 4),
              const Text(
                'この端末の中にだけ保存されます。サーバーには何も送りません（AI提案の生成時を除く）',
                style: TextStyle(
                    fontSize: 12, height: 1.6, color: AdhtColors.muted),
              ),
              const SizedBox(height: 10),
              TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: AdhtColors.red,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: () async {
                  final ok = await showConfirmDialog(
                    context,
                    title: 'サンプルデータに戻す',
                    message: '現在のタスクをすべて消して、サンプルタスクに戻します。',
                    okLabel: '戻す',
                  );
                  if (ok) store.resetToSeed();
                },
                child: const Text('サンプルデータに戻す',
                    style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toneChip(Tone tone, String label) {
    final active = store.settings.tone == tone;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          store.setTone(tone);
          setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.white : const Color(0xFFECECF1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: active ? AdhtColors.accent : Colors.transparent,
                width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
        ),
      ),
    );
  }

  Widget _group({required String label, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AdhtColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ...children,
        ],
      ),
    );
  }
}
