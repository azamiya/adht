import 'package:flutter/material.dart';

import 'screens/briefing_screen.dart';
import 'screens/consult_screen.dart';
import 'screens/create_task_sheet.dart';
import 'screens/settings_screen.dart';
import 'screens/task_detail_screen.dart';
import 'screens/task_list_screen.dart';
import 'store/app_store.dart';
import 'ui/style.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.load();
  runApp(AdhtApp(store: store));
}

class AdhtApp extends StatelessWidget {
  const AdhtApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADHT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AdhtColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AdhtColors.accent,
          surface: AdhtColors.bg,
        ),
        fontFamilyFallback: const ['Hiragino Sans'],
      ),
      home: HomeShell(store: store),
    );
  }
}

/// タブシェル: ☀️今日（ブリーフィング）/ ☑︎タスク / ⚙︎設定
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});

  final AppStore store;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  AppStore get store => widget.store;

  Future<void> _addTask() async {
    final result = await showTaskSheet(context, store);
    if (result != null && mounted) {
      // 保存と同時にAI提案を自動生成（詳細画面側で生成が走る、仕様 §2.2）
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              TaskDetailScreen(store: store, taskId: result.task.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Scaffold(
          body: IndexedStack(
            index: _tab,
            children: [
              BriefingScreen(store: store),
              TaskListScreen(store: store),
              ConsultScreen(store: store),
              SettingsScreen(store: store),
            ],
          ),
          floatingActionButton: _tab == 1
              ? FloatingActionButton(
                  onPressed: _addTask,
                  backgroundColor: AdhtColors.accent,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.add, size: 30),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            backgroundColor: const Color(0xFFF9F9FB),
            indicatorColor: AdhtColors.accentWeak,
            destinations: const [
              NavigationDestination(
                  icon: Text('☀️', style: TextStyle(fontSize: 22)),
                  label: '今日'),
              NavigationDestination(
                  icon: Icon(Icons.check_box_outlined), label: 'タスク'),
              NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline), label: '相談'),
              NavigationDestination(
                  icon: Icon(Icons.settings_outlined), label: '設定'),
            ],
          ),
        );
      },
    );
  }
}
