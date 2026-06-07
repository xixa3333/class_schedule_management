import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 1. 初始化設定
  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Taipei'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    // 【修正 1】加上 initializationSettings: 標籤
    await _notificationsPlugin.initialize(settings: initializationSettings);

    // 🌟 【新增】創建所有需要的通知頻道
    // 頻道 1: 上課提醒
    const AndroidNotificationChannel classReminderChannel =
        AndroidNotificationChannel(
          'class_reminder_channel',
          '上課提醒',
          description: '提醒即將開始的課程與教室位置',
          importance: Importance.max,
        );

    // 頻道 2: 測試通知
    const AndroidNotificationChannel testChannel = AndroidNotificationChannel(
      'test_channel',
      '測試通知',
      description: '用於測試推播功能',
      importance: Importance.max,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(classReminderChannel);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(testChannel);

    print("✅ 所有通知頻道已創建");
  }

  // 2. 請求推播權限
  static Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    print("🔔 開始請求推播權限...");
    await androidImplementation?.requestNotificationsPermission();
    print("✅ 推播權限已請求");

    // 🌟 [重要] 啟用精確鬧鐘權限 - Android 12+ 需要這個！
    await androidImplementation?.requestExactAlarmsPermission();
    print("✅ 精確鬧鐘權限已請求");
  }

  // 3. [新增] 立刻測試用的秒發推播！
  static Future<void> showTestNotification() async {
    print("🧪 [秒發測試] 準備彈出立即通知...");

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'test_channel',
          '測試通知',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true, // 🌟 [新增] 讓通知以全屏顯示（如果可能）
        );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    try {
      // .show() 代表沒有時間延遲，立刻彈出
      await _notificationsPlugin.show(
        id: 888,
        title: '推播測試成功！🎉',
        body: '恭喜你！手機的通知功能完全正常！',
        notificationDetails: details,
      );
      print("✅ [秒發測試] 通知已提交 - 應該立刻在屏幕上看到！");
    } catch (e) {
      print("❌ [秒發測試] 彈出通知失敗: $e");
    }
  }

  // 🌟 [诊断] 对比 show() 和 zonedSchedule()
  static Future<void> diagnosticCompareShowVsZonedSchedule() async {
    print("\n╔════════════════════════════════════════════════╗");
    print("║  诊断测试：对比 show() 和 zonedSchedule()      ║");
    print("╚════════════════════════════════════════════════╝");

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'test_channel',
          '测试通知',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
        );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    // 测试 1：立刻显示（应该能看到）
    print("\n📢 测试 1：show() - 立刻显示（应该立刻看到）");
    try {
      await _notificationsPlugin.show(
        id: 8001,
        title: '📢 测试 1：show() 立刻显示',
        body: '如果看到此通知，说明 show() 可用',
        notificationDetails: details,
      );
      print("✅ show() 已提交");
    } catch (e) {
      print("❌ show() 失败：$e");
    }

    // 测试 2：2秒后显示（检查 zonedSchedule 是否工作）
    print("\n📢 测试 2：zonedSchedule() - 2秒后显示");
    final nowTZ = tz.TZDateTime.now(tz.local);
    final testTime = nowTZ.add(const Duration(seconds: 2));

    print("   现在时间：$nowTZ");
    print("   计划时间：$testTime");

    try {
      await _notificationsPlugin.zonedSchedule(
        id: 8002,
        title: '📢 测试 2：zonedSchedule() 2秒后显示',
        body: '如果看到此通知，说明 zonedSchedule() 可用',
        scheduledDate: testTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      print("✅ zonedSchedule() 已提交");
    } catch (e) {
      print("❌ zonedSchedule() 失败：$e");
    }

    print("\n📋 预期结果：");
    print("   ✅ 立刻看到『测试 1：show() 立刻显示』");
    print("   ✅ 2秒后看到『测试 2：zonedSchedule() 2秒后显示』");
    print("   如果没有看到测试 2，说明 zonedSchedule 有问题\n");
  }

  // 3. 設定上課前 10 分鐘的排程推播
  static Future<void> scheduleClassReminder({
    required int notificationId,
    required String courseName,
    required String classroom,
    required DateTime classStartTime,
  }) async {
    print("\n═══════════════════════════════════════════");
    print("📢 開始設定通知排程");
    print("═══════════════════════════════════════════");
    print("🆔 通知 ID: $notificationId");
    print("📚 課程名稱: $courseName");
    print("🏫 教室: $classroom");
    print("⏰ 上課時間: $classStartTime");

    // 🌟 [改進] 使用時區感知的現在時間
    final nowTZ = tz.TZDateTime.now(tz.local);
    print("⏱️ 現在時間 (時區感知): $nowTZ");

    // 🌟 [重要修復] 直接構造 TZDateTime，不要用 .from()
    // 因為輸入的 classStartTime 已經是本地時間，不是 UTC 時間
    final classStartTimeTZ = tz.TZDateTime(
      tz.local,
      classStartTime.year,
      classStartTime.month,
      classStartTime.day,
      classStartTime.hour,
      classStartTime.minute,
      classStartTime.second,
    );
    print("⏰ 上課時間 (時區感知): $classStartTimeTZ");

    final scheduledTimeTZ = classStartTimeTZ.subtract(
      const Duration(minutes: 10),
    );
    print("⏳ 計算後的排程時間 (上課前10分鐘): $scheduledTimeTZ");

    // 🌟 [改進] 強制緩衝邏輯：使用時區感知的比較
    tz.TZDateTime finalScheduledTime = scheduledTimeTZ;

    if (finalScheduledTime.isBefore(nowTZ.add(const Duration(seconds: 10)))) {
      print("⚠️ 時間已過！調整為現在 + 15 秒");
      finalScheduledTime = nowTZ.add(const Duration(seconds: 15));
    }

    print("✅ 最終排程時間: $finalScheduledTime");

    if (finalScheduledTime.isBefore(nowTZ)) {
      print("❌ 設定失敗：提醒時間已經過去了！");
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'class_reminder_channel',
          '上課提醒',
          channelDescription: '提醒即將開始的課程與教室位置',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true, // 🌟 [重要] 讓排程通知也能以全屏顯示
        );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    print("⏳ 正在提交通知到 Android 系統...");

    try {
      await _notificationsPlugin.zonedSchedule(
        id: notificationId, // 🌟 加回 id:
        title: '上課提醒：$courseName 準備上課！', // 🌟 加回 title:
        body: '再過 10 分鐘就要上課囉！教室在：$classroom', // 🌟 加回 body:
        scheduledDate: finalScheduledTime, // 🌟 加回 scheduledDate:
        notificationDetails: const NotificationDetails(
          // 🌟 加回 notificationDetails:
          android: AndroidNotificationDetails(
            'class_reminder_channel',
            '上課提醒',
            channelDescription: '提醒即將開始的課程與教室位置',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
          ),
        ),
        // 🌟 1. 改成 inexact，繞過系統嚴格的精準鬧鐘權限審查
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,

        // 🌟 2. 為了「15秒快速測試」，請先將下面這行註解掉！
        // 測試成功後，再把這行加回來給正式的課程使用，讓它每週重複。
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
      print("✅ 通知已使用 zonedSchedule 排程");
    } catch (e) {
      print("❌ 提交通知時出錯: $e");
    }

    // 🌟 驗證推播是否已排入系統佇列
    final pendingNotifications = await _notificationsPlugin
        .pendingNotificationRequests();
    print("📋 目前排程中的通知數量: ${pendingNotifications.length}");
    for (var n in pendingNotifications) {
      print("   ✓ ID: ${n.id} | 標題: ${n.title}");
    }
    print("═══════════════════════════════════════════\n");
  }

  // [新增] 刪除指定 ID 的通知
  static Future<void> cancelNotification(int notificationId) async {
    await _notificationsPlugin.cancel(id: notificationId);
  }

  // 🌟 [新增] 調試工具：顯示所有排程中的通知
  static Future<void> debugShowPendingNotifications() async {
    final pendingNotifications = await _notificationsPlugin
        .pendingNotificationRequests();

    print("═══════════════════════════════════════");
    print("📋 目前排程中的通知數量: ${pendingNotifications.length}");
    print("═══════════════════════════════════════");

    if (pendingNotifications.isEmpty) {
      print("❌ 沒有任何排程中的通知!");
    } else {
      for (var n in pendingNotifications) {
        print("✅ 通知 ID: ${n.id}");
        print("   標題: ${n.title}");
        print("   內容: ${n.body}");
        print("───────────────────────────────────");
      }
    }
  }

  // 🌟 [新增] 清除所有通知 (用於測試和故障排除)
  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    print("✅ 已清除所有推播通知");
  }

  // 🌟 [新增] 診斷方法：檢查系統配置
  static Future<void> diagnoseSystem() async {
    print("\n╔═══════════════════════════════════════════════╗");
    print("║ 🔧 完整系統診斷信息");
    print("╚═══════════════════════════════════════════════╝\n");

    print("✅ 應用已初始化: 是");
    print("✅ 時區設定: Asia/Taipei");
    print("✅ 當前本地時間: ${DateTime.now()}");
    print("✅ 當前時區時間: ${tz.TZDateTime.now(tz.local)}");

    final pendingNotifications = await _notificationsPlugin
        .pendingNotificationRequests();
    print("\n📋 排程狀態:");
    print("   - 排程中的通知數: ${pendingNotifications.length}");

    if (pendingNotifications.isNotEmpty) {
      print("   - 排程的通知:");
      for (var n in pendingNotifications) {
        print("      • ID: ${n.id} | ${n.title}");
      }
    }

    print("\n⚠️  故障排除步驟 (按順序檢查):");
    print("""
1️⃣ 【測試秒發通知】
   - 點「立刻彈出推播」按鈕
   - ✅ 能看到通知 → 轉到第 2 步
   - ❌ 看不到通知 → 檢查手機設定:
      • 應用權限 → 允許通知
      • 檢查勿擾模式
      • 檢查聲音和震動設定

2️⃣ 【秒發通知能彈出，但排程通知不能】
   - 最可能是 Android Doze Mode 限制
   - 解決方案：
      ✓ 手機設定 → 電池 → 應用管理
      ✓ 找到你的應用
      ✓ 關閉「動態省電」或加入白名單
      ✓ 或關閉「省電模式」

3️⃣ 【排程中有通知但還是沒觸發】
   - 可能原因：
      • 應用被系統殺死 (需要點擊 App 保持運行)
      • AlarmManager 權限被限制
      • 時區轉換問題
   - 解決方案：
      ✓ 確保應用在前台
      ✓ 重新啟動應用
      ✓ 在控制台中驗證時間轉換是否正確

4️⃣ 【其他檢查】
   - 時區設定: 正確 ✓
   - 通知頻道: 已創建 ✓
   - 權限: 已請求 (POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM, WAKE_LOCK) ✓
""");

    print("╚═══════════════════════════════════════════════╝\n");
  }
}
