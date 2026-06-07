import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_settings.dart';
import '../services/course_service.dart';

class SettingsProvider with ChangeNotifier {
  final _service = CourseService();

  // 內部變數
  ThemeMode _themeMode = ThemeMode.system;
  int _maxPeriods = 13;
  int _morningStartHour = 8;
  int _morningStartMinute = 10;
  int _afternoonStartHour = 13;
  int _afternoonStartMinute = 30;

  // Getters
  ThemeMode get themeMode => _themeMode;
  int get maxPeriods => _maxPeriods;
  String get morningStartTime => "${_format(_morningStartHour)}:${_format(_morningStartMinute)}";
  String get afternoonStartTime => "${_format(_afternoonStartHour)}:${_format(_afternoonStartMinute)}";

  // 建構子
  SettingsProvider() {
    // [關鍵] 監聽登入狀態改變
    // 一旦登入 (User A) -> 載入 A 的設定
    // 一旦登出 -> 載入預設值
    FirebaseAuth.instance.authStateChanges().listen((user) {
      loadSettings();
    });

    // 初始化先載入一次
    loadSettings();
  }

  // --- 核心邏輯：從資料庫讀取 ---
  Future<void> loadSettings() async {
    // 從 Service 獲取 UserSettings 物件
    final settings = await _service.getUserSettings();

    // 更新記憶體中的變數
    _themeMode = ThemeMode.values[settings.themeModeIndex];
    _maxPeriods = settings.maxPeriods;
    _morningStartHour = settings.morningStartHour;
    _morningStartMinute = settings.morningStartMinute;
    _afternoonStartHour = settings.afternoonStartHour;
    _afternoonStartMinute = settings.afternoonStartMinute;

    notifyListeners();
  }

  // --- 輔助：儲存當前狀態回資料庫 ---
  Future<void> _saveToDb() async {
    final settings = UserSettings()
      ..themeModeIndex = _themeMode.index
      ..maxPeriods = _maxPeriods
      ..morningStartHour = _morningStartHour
      ..morningStartMinute = _morningStartMinute
      ..afternoonStartHour = _afternoonStartHour
      ..afternoonStartMinute = _afternoonStartMinute;

    // userId 會在 Service 裡補上

    await _service.updateUserSettings(settings);
  }

  // --- Setters (修改後自動存檔) ---

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _saveToDb();
  }

  Future<void> setMaxPeriods(int count) async {
    _maxPeriods = count;
    notifyListeners();
    await _saveToDb();
  }

  Future<void> setMorningStartTime(int hour, int minute) async {
    _morningStartHour = hour;
    _morningStartMinute = minute;
    notifyListeners();
    await _saveToDb();
  }

  Future<void> setAfternoonStartTime(int hour, int minute) async {
    _afternoonStartHour = hour;
    _afternoonStartMinute = minute;
    notifyListeners();
    await _saveToDb();
  }

  String getPeriodStartTime(int period) {
    int h, m;
    if (period <= 4) {
      h = _morningStartHour + (period - 1);
      m = _morningStartMinute;
    } else {
      h = _afternoonStartHour + (period - 5);
      m = _afternoonStartMinute;
    }
    return "${_format(h)}:${_format(m)}";
  }

  String _format(int n) => n.toString().padLeft(2, '0');
}