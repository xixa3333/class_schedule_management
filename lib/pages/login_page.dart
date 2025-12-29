import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLogin = true; // true=登入模式, false=註冊模式
  bool _isLoading = false;

  // [新增] 重設密碼邏輯
  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();

    // 1. 檢查有沒有輸入 Email
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先輸入您的 Email，才能發送重設信件')),
      );
      return;
    }

    try {
      // 2. 呼叫 Firebase 發送重設信
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('信件已發送'),
            content: Text('重設密碼的連結已寄送到 $email。\n請檢查您的信箱（包含垃圾郵件夾）。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('好'),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      // 處理錯誤 (例如 Email 格式不對，或是該 Email 沒註冊過)
      String message = '發送失敗：${e.message}';
      if (e.code == 'user-not-found') {
        message = '此 Email 尚未註冊過帳號';
      } else if (e.code == 'invalid-email') {
        message = 'Email 格式不正確';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  // 執行登入或註冊
  Future<void> _submit() async {
    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // 登入
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
        );
      } else {
        // 註冊
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? '發生錯誤')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school, size: 80, color: Theme.of(context).primaryColor),
              const SizedBox(height: 20),
              Text(
                _isLogin ? '歡迎回來' : '註冊新帳號',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              // 輸入框
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(
                  labelText: '密碼',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),

              // [新增] 只有在「登入模式」才顯示忘記密碼按鈕
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _resetPassword,
                    child: const Text('忘記密碼？', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                const SizedBox(height: 24), // 註冊模式補一點間距

              // 按鈕
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Text(_isLogin ? '登入' : '註冊', style: const TextStyle(fontSize: 18)),
                ),
              ),

              const SizedBox(height: 16),

              // 切換模式
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin ? '還沒有帳號？去註冊' : '已有帳號？去登入'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}