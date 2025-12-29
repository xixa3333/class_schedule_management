import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'schedule_page.dart';
import 'login_page.dart'; // 等下建立

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // 監聽 Firebase 的登入狀態變化
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 如果 snapshot 有資料，代表使用者已登入
        if (snapshot.hasData) {
          return const SchedulePage();
        }

        // 否則顯示登入頁面
        return const LoginPage();
      },
    );
  }
}