import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/task.dart';
import '../store/app_store.dart';
import '../ui/style.dart';

/// アプリのバージョン（SemVer 2.0.0、仕様書とメジャー.マイナーを揃える。pubspec.yaml と同期）
const String kAppVersion = '1.3.0';

/// ⑥ 設定: 口調・ブリーフィング時刻・JSONインポート/エクスポート（仕様 §2.4）
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

  /* ---- エクスポート（仕様 §2.4 v1.3: コピー / ファイル保存） ---- */

  Future<void> _exportCopy() async {
    final json = store.exportJson();
    _ioController.text = json;
    await Clipboard.setData(ClipboardData(text: json));
    _setStatus('✓ ${store.tasks.length}件をクリップボードにコピーしました');
  }

  Future<void> _exportFile() async {
    try {
      final now = DateTime.now();
      final name =
          'adht-tasks-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.json';
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsString(store.exportJson());
      // iOS は共有シート経由でファイル/AirDrop 等へ保存
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'application/json')]),
      );
      _setStatus('✓ ${store.tasks.length}件を $name として書き出しました');
    } catch (e) {
      _setStatus('ファイル保存に失敗しました: $e', error: true);
    }
  }

  /* ---- インポート（仕様 §2.4 v1.3: 貼り付け / ファイル選択） ---- */

  Future<void> _runImport(String raw) async {
    final result = store.parseImport(raw);
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

  Future<void> _importPaste() => _runImport(_ioController.text);

  Future<void> _importFile() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (picked == null) return; // キャンセル
      final text = utf8.decode(await picked.readAsBytes());
      _ioController.text = text;
      await _runImport(text);
    } catch (e) {
      _setStatus('ファイルを読み込めませんでした: $e', error: true);
    }
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
            label: 'ブリーフィングの口調',
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
              const Text('バージョンアップでデータ形式が変わっても、JSONで引っ越せます',
                  style: TextStyle(
                      fontSize: 12, height: 1.6, color: AdhtColors.muted)),
              _ioLabel('📤 エクスポート'),
              Row(
                children: [
                  _ioBtn('📋 コピー', accent: true, onTap: _exportCopy),
                  const SizedBox(width: 8),
                  _ioBtn('💾 ファイル保存', accent: true, onTap: _exportFile),
                ],
              ),
              _ioLabel('📥 インポート'),
              Row(
                children: [
                  _ioBtn('📋 貼り付けを取り込む', accent: false, onTap: _importPaste),
                  const SizedBox(width: 8),
                  _ioBtn('📁 ファイルを選ぶ', accent: false, onTap: _importFile),
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
                      'コピー: ここにJSONが出ます（クリップボードにも自動コピー）\n貼り付けインポート: ここにJSONを貼って「貼り付けを取り込む」',
                  hintStyle: const TextStyle(fontSize: 11, height: 1.5),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFC),
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AdhtColors.separator),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AdhtColors.separator),
                  ),
                ),
              ),
              if (_ioStatus.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_ioStatus,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _ioError ? AdhtColors.red : AdhtColors.green)),
              ],
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('ADHT v$kAppVersion',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AdhtColors.muted)),
          ),
        ],
      ),
    );
  }

  Widget _ioLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AdhtColors.muted)),
    );
  }

  Widget _ioBtn(String label,
      {required bool accent, required VoidCallback onTap}) {
    return Expanded(
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: accent ? AdhtColors.accent : const Color(0xFFF0F0F5),
          foregroundColor: accent ? Colors.white : AdhtColors.text,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        ),
        onPressed: onTap,
        child: Text(label,
            style:
                const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
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
