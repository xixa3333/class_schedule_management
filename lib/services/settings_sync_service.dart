import 'dart:async';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_settings.dart';
// 如果有 CourseSchema 的需求請確保正確匯入
// import '../models/course.dart';

class SettingsSyncService {
  late Future<Isar> db;
  Timer? _syncTimer;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SettingsSyncService() {
    db = _getIsarInstance();
  }

  // 確保不會與 CourseService 發生 Isar 重複開啟的衝突
  Future<Isar> _getIsarInstance() async {
    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      // 注意：這裡必須包含你所有的 Schema，確保與 CourseService 一致
      return await Isar.open(
        [UserSettingsSchema], // 若有 CourseSchema 請一併加入 [CourseSchema, UserSettingsSchema]
        directory: dir.path,
      );
    }
    return Future.value(Isar.getInstance());
  }

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  // 安全初始化同步流程
  Future<void> initializeSync() async {
    if (currentUserId == null) return;
    await restoreSettingsFromCloud();
    await syncUnsyncedSettings();
  }

  // 從雲端拉取設定並合併至本地
  Future<void> restoreSettingsFromCloud() async {
    final uid = currentUserId;
    if (uid == null) return;

    final isar = await db;
    final docRef = _firestore.collection('users').doc(uid).collection('settings').doc('user_prefs');

    try {
      final snapshot = await docRef.get();
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final cloudUpdatedAt = data['updatedAt'] as int? ?? 0;

      await isar.writeTxn(() async {
        final localSettings = await isar.userSettings.filter().userIdEqualTo(uid).findFirst();

        // 雲端較新，或本地無資料時，執行覆寫
        if (localSettings == null || cloudUpdatedAt > localSettings.updatedAt) {
          final newSettings = UserSettings()
            ..id = localSettings?.id ?? Isar.autoIncrement // 保留原 ID 避免 unique 衝突
            ..userId = uid
            ..maxPeriods = data['maxPeriods'] ?? 13
            ..morningStartHour = data['morningStartHour'] ?? 8
            ..morningStartMinute = data['morningStartMinute'] ?? 10
            ..afternoonStartHour = data['afternoonStartHour'] ?? 13
            ..afternoonStartMinute = data['afternoonStartMinute'] ?? 30
            ..themeModeIndex = data['themeModeIndex'] ?? 0
            ..updatedAt = cloudUpdatedAt
            ..isSynced = true;

          await isar.userSettings.put(newSettings);
        }
      });
      print('雲端設定檔下載與合併完成');
    } catch (e) {
      print('拉取雲端設定檔失敗: $e');
    }
  }

  // UI 層呼叫的更新方法 (帶防抖)
  Future<void> saveSettings(UserSettings settings) async {
    final isar = await db;
    final uid = currentUserId;

    if (uid == null) return;

    settings.userId = uid;
    settings.updatedAt = DateTime.now().millisecondsSinceEpoch;
    settings.isSynced = false;

    await isar.writeTxn(() async {
      await isar.userSettings.put(settings);
    });

    _triggerSync();
  }

  void _triggerSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 3), () => syncUnsyncedSettings());
  }

  // 將本地未同步的設定推上雲端
  Future<void> syncUnsyncedSettings() async {
    final uid = currentUserId;
    if (uid == null) return;

    final isar = await db;
    final unsyncedSettings = await isar.userSettings
        .filter()
        .userIdEqualTo(uid)
        .isSyncedEqualTo(false)
        .findFirst();

    if (unsyncedSettings == null) return;

    final docRef = _firestore.collection('users').doc(uid).collection('settings').doc('user_prefs');

    try {
      await docRef.set(unsyncedSettings.toFirestore(), SetOptions(merge: true));

      await isar.writeTxn(() async {
        unsyncedSettings.isSynced = true;
        await isar.userSettings.put(unsyncedSettings);
      });
      print('雲端設定檔同步完成');
    } catch (e) {
      print('設定檔同步失敗: $e');
    }
  }
}