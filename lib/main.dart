import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart'; // [新增]
import 'firebase_options.dart';
import 'pages/auth_gate.dart';
import 'providers/settings_provider.dart'; // [新增]
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print("應用啟動中...");

  // [新增] 初始化推播服務
  print("正在初始化推播服務...");
  await NotificationService.init();
  print("推播服務初始化完成");

  // [新增] 應用啟動時立即請求推播權限
  print("請求推播和鬧鐘權限...");
  await NotificationService.requestPermissions();
  print("所有權限已請求");

  runApp(
    // [新增] 使用 ChangeNotifierProvider 包住整個 App
    ChangeNotifierProvider(
      create: (context) => SettingsProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // [新增] 監聽設定變化
    final settings = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      title: 'NKUST 課表',
      debugShowCheckedModeBanner: false,

      // [設定] 主題模式設定
      themeMode: settings.themeMode,

      // 亮色主題
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),

      // [新增] 深色主題
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true, // Material 3 的深色模式非常漂亮
      ),

      home: const AuthGate(),
    );
  }
}
