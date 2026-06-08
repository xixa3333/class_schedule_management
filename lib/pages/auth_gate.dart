import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'schedule_page.dart';
import '../services/course_service.dart';
import '../services/settings_sync_service.dart'; // 引入新的 Service

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return const LoginPage();
        }

        return const SyncWrapper(
          child: SchedulePage(),
        );
      },
    );
  }
}

class SyncWrapper extends StatefulWidget {
  final Widget child;
  const SyncWrapper({super.key, required this.child});

  @override
  State<SyncWrapper> createState() => _SyncWrapperState();
}

class _SyncWrapperState extends State<SyncWrapper> {
  bool _isSyncing = true;
  String _syncMessage = '正在與雲端同步資料...';

  @override
  void initState() {
    super.initState();
    _performSync();
  }

  Future<void> _performSync() async {
    try {
      // 將序列化等待包裝在一個有時間限制的 Future 中
      await Future(() async {

        // 1. 先同步設定檔 (包裝獨立 try-catch 避免阻斷)
        try {
          await SettingsSyncService().initializeSync();
        } catch (e) {
          print('設定檔同步失敗: $e');
        }

        // 2. 設定檔就位後，再同步課表
        try {
          await CourseService().initializeSync();
        } catch (e) {
          print('課表同步失敗: $e');
        }

      }).timeout(
        const Duration(seconds: 5), // 總體超時限制設定為 5 秒
      );
    } on TimeoutException {
      print('整體同步超時，先進入主畫面，背景將持續重試');
    } catch (e) {
      print('同步過程發生非預期錯誤: $e');
    } finally {
      // 確保元件還在畫面上才更新狀態，避免 dispose 崩潰
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSyncing) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _syncMessage,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '保持最新狀態中，請稍候',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}