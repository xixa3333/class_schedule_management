import 'dart:async'; // [新增] 用於防抖 Timer
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // [新增] Firestore
import '../models/course.dart';
import '../models/user_settings.dart';
import '../models/friend.dart';
import 'widget_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class CourseService {
  late Future<Isar> db;
  Timer? _syncTimer;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CourseService() {
    db = openDB();
    setupConnectivityListener();
  }

  void setupConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // 若包含非 none 的連線結果，表示已連線
      if (results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.mobile)) {
        print('網路已恢復，觸發同步...');
        initializeSync();
      }
    });
  }

  Future<void> _mergeCourse(Isar isar, Course localCourse, Map<String, dynamic> cloudData) async {
    final cloudUpdatedAt = cloudData['updatedAt'] as int? ?? 0;

    // 核心邏輯：若雲端資料較新，才進行更新
    if (cloudUpdatedAt > localCourse.updatedAt) {
      await isar.writeTxn(() async {
        localCourse
          ..semester = cloudData['semester']
          ..courseName = cloudData['courseName']
          ..classroom = cloudData['classroom']
          ..teacher = cloudData['teacher']
          ..dayOfWeek = cloudData['dayOfWeek']
          ..startPeriod = cloudData['startPeriod']
          ..endPeriod = cloudData['endPeriod']
          ..colorHex = cloudData['colorHex'] ?? 0xFF2196F3
          ..note = cloudData['note']
          ..enableNotification = cloudData['enableNotification'] ?? true
          ..credits = (cloudData['credits'] as num?)?.toDouble() ?? 0.0
          ..score = (cloudData['score'] as num?)?.toDouble()
          ..updatedAt = cloudUpdatedAt
          ..isSynced = true
          ..isDeleted = cloudData['isDeleted'] ?? false;

        await isar.courses.put(localCourse);
      });
    }
  }

  // [新增] 取得該使用者「所有曾經建立過資料」的學期列表 (去重複)
  Future<List<String>> getUsedSemesters() async {
    final isar = await db;
    final uid = currentUserId;

    if (uid == null) return [];

    // 1. 找出該使用者所有的課
    final courses = await isar.courses
        .filter()
        .userIdEqualTo(uid)
        .isDeletedEqualTo(false)
        .findAll();

    // 2. 取出 semester 欄位，並用 Set 去除重複
    final distinctSemesters = courses.map((e) => e.semester).toSet().toList();

    return distinctSemesters;
  }

  Future<Isar> openDB() async {
    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      return await Isar.open(
        [CourseSchema, UserSettingsSchema, FriendSchema], // [修改] 加入 FriendSchema
        directory: dir.path,
        inspector: true, // 開發模式下可以開啟檢測器
      );
    }
    return Future.value(Isar.getInstance());
  }

  // [修改] 取得目前登入的 User ID
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Future<void> initializeSync() async {
    if (currentUserId == null) return;
    // 必須先下載最新資料，再把本地未上傳的髒資料推上去
    await restoreDataFromCloud();
    await syncUnsyncedData();
  }

  Future<void> restoreDataFromCloud() async {
    final uid = currentUserId;
    if (uid == null) return;

    final isar = await db;
    final collection = _firestore.collection('users').doc(uid).collection('courses');

    try {
      final snapshot = await collection.get();
      if (snapshot.docs.isEmpty) return;

      await isar.writeTxn(() async {
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final cloudId = int.tryParse(doc.id);
          if (cloudId == null) continue;

          final localCourse = await isar.courses.get(cloudId);
          final cloudUpdatedAt = data['updatedAt'] as int? ?? 0;

          // Last-Write-Wins: 雲端資料較新，或是本地完全沒這筆資料時，覆寫本地
          if (localCourse == null) {
            final newCourse = Course()
              ..id = cloudId
              ..userId = data['userId']
              ..semester = data['semester']
              ..courseName = data['courseName']
              ..classroom = data['classroom']
              ..teacher = data['teacher']
              ..dayOfWeek = data['dayOfWeek']
              ..startPeriod = data['startPeriod']
              ..endPeriod = data['endPeriod']
              ..colorHex = data['colorHex'] ?? 0xFF2196F3
              ..note = data['note']
              ..enableNotification = data['enableNotification'] ?? true
              ..credits = (data['credits'] as num?)?.toDouble() ?? 0.0
              ..score = (data['score'] as num?)?.toDouble()
              ..updatedAt = cloudUpdatedAt
              ..isSynced = true // 從雲端拉下來的資料視為已同步
              ..isDeleted = data['isDeleted'] ?? false;

            await isar.courses.put(newCourse);
          }
          else{
            await _mergeCourse(isar, localCourse, data);
          }
        }
      });
      print('雲端資料同步完成');
    } catch (e) {
      print('拉取雲端資料失敗: $e');
    }
  }

  // [修改] 新增或修改課程
  Future<void> saveCourse(Course course) async {
    final isar = await db;
    final uid = currentUserId;

    if (uid == null) return;

    course.userId = uid;
    course.updatedAt = DateTime.now().millisecondsSinceEpoch; // 更新時間
    course.isSynced = false; // 標記為髒資料

    await isar.writeTxn(() async {
      await isar.courses.put(course);
    });

    await WidgetService.updateWidgetData(isar);
    _triggerSync(); // 觸發防抖同步
  }

  // [修改] 根據學期取得課程列表 (只拿自己的!)
  Future<List<Course>> getCoursesBySemester(String semester) async {
    final isar = await db;
    final uid = currentUserId;

    if (uid == null) return []; // 沒登入就回傳空陣列

    return await isar.courses
        .filter()
        .userIdEqualTo(uid) // [關鍵] 只篩選自己的 ID
        .semesterEqualTo(semester)
        .isDeletedEqualTo(false)
        .findAll();
  }

  // [修改] 檢查課程衝突 (只檢查自己的!)
  Future<bool> isTimeConflict(Course newCourse) async {
    final isar = await db;
    final uid = currentUserId;

    if (uid == null) return false;

    final existingCourses = await isar.courses
        .filter()
        .userIdEqualTo(uid)
        .semesterEqualTo(newCourse.semester)
        .dayOfWeekEqualTo(newCourse.dayOfWeek)
        .isDeletedEqualTo(false) // [關鍵] 忽略已刪除的課
        .findAll();

    for (var existing in existingCourses) {
      if (existing.id == newCourse.id) continue;
      if (newCourse.startPeriod <= existing.endPeriod &&
          newCourse.endPeriod >= existing.startPeriod) {
        return true;
      }
    }
    return false;
  }

  // 刪除課程 (ID 是唯一的，通常不需要改 filter，但為了安全也可以加)
  Future<void> deleteCourse(int id) async {
    final isar = await db;
    final course = await isar.courses.get(id);

    if (course != null) {
      course.isDeleted = true; // 標記為刪除
      course.updatedAt = DateTime.now().millisecondsSinceEpoch;
      course.isSynced = false; // 標記為髒資料

      await isar.writeTxn(() async {
        await isar.courses.put(course);
      });

      await WidgetService.updateWidgetData(isar);
      _triggerSync(); // 觸發防抖同步
    }
  }

  void _triggerSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 3), () => syncUnsyncedData());
  }

  Future<void> syncUnsyncedData() async {
    final uid = currentUserId;
    if (uid == null) return;

    final isar = await db;
    // 找出所有需要同步的資料
    final unsyncedCourses = await isar.courses
        .filter()
        .userIdEqualTo(uid)
        .isSyncedEqualTo(false)
        .findAll();

    if (unsyncedCourses.isEmpty) return;

    // 使用 Firestore 的 WriteBatch 批次寫入節省讀寫次數
    final batch = _firestore.batch();
    final collection = _firestore.collection('users').doc(uid).collection('courses');

    for (var course in unsyncedCourses) {
      // 使用 Isar 的 id 作為 Firestore 的 document ID
      final docRef = collection.doc(course.id.toString());
      batch.set(docRef, course.toFirestore(), SetOptions(merge: true));
    }

    try {
      await batch.commit(); // 提交至雲端

      // 若上傳成功，將本地資料標記為已同步
      await isar.writeTxn(() async {
        for (var course in unsyncedCourses) {
          course.isSynced = true;
          await isar.courses.put(course);
        }
      });
      print('雲端同步完成，共上傳 ${unsyncedCourses.length} 筆資料');
    } catch (e) {
      print('同步失敗，將於下次觸發時重試: $e');
    }
  }

  // [新增] 取得該使用者「所有學期」的課程 (用於統計)
  Future<List<Course>> getAllCoursesByUser() async {
    final isar = await db;
    final uid = currentUserId;

    if (uid == null) return [];

    return await isar.courses
        .filter()
        .userIdEqualTo(uid)
        .isDeletedEqualTo(false)
        .findAll();
  }

  // [新增] 取得目前使用者的設定 (如果沒有，回傳預設值)
  Future<UserSettings> getUserSettings() async {
    final isar = await db;
    final uid = currentUserId;

    if (uid == null) return UserSettings(); // 沒登入回傳預設物件

    // 嘗試從資料庫找
    final settings = await isar.userSettings
        .filter()
        .userIdEqualTo(uid)
        .findFirst();

    // 如果找到就回傳，找不到就回傳新的預設物件 (並綁定 UID)
    return settings ?? UserSettings()..userId = uid;
  }

  // [新增] 儲存設定
  Future<void> updateUserSettings(UserSettings settings) async {
    final isar = await db;
    final uid = currentUserId;

    if (uid == null) return;

    settings.userId = uid; // 確保綁定目前使用者

    await isar.writeTxn(() async {
      await isar.userSettings.put(settings);
    });
  }
}