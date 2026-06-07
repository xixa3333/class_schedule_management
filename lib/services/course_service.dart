import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // [新增] 匯入這行
import '../models/course.dart';
import '../models/user_settings.dart'; // [新增]

class CourseService {
  late Future<Isar> db;

  CourseService() {
    db = openDB();
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
        .findAll();

    // 2. 取出 semester 欄位，並用 Set 去除重複
    final distinctSemesters = courses.map((e) => e.semester).toSet().toList();

    return distinctSemesters;
  }

  Future<Isar> openDB() async {
    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      return await Isar.open(
        [CourseSchema, UserSettingsSchema], // [修改] 加入 UserSettingsSchema
        directory: dir.path,
        inspector: true, // 開發模式下可以開啟檢測器
      );
    }
    return Future.value(Isar.getInstance());
  }

  // [修改] 取得目前登入的 User ID
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  // [修改] 新增或修改課程
  Future<void> saveCourse(Course course) async {
    final isar = await db;
    final uid = currentUserId; // 取得 UID

    if (uid == null) {
      // 如果沒登入 (理論上不會發生)，可以選擇不存或拋出錯誤
      // 這裡簡單處理：直接 return
      print("尚未登入，無法儲存");
      return;
    }

    // 綁定 User ID
    course.userId = uid;

    await isar.writeTxn(() async {
      await isar.courses.put(course);
    });
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
        .findAll();
  }

  // [修改] 檢查課程衝突 (只檢查自己的!)
  Future<bool> isTimeConflict(Course newCourse) async {
    final isar = await db;
    final uid = currentUserId;

    if (uid == null) return false;

    // 1. 找出該使用者、該學期、該星期幾的所有課程
    final existingCourses = await isar.courses
        .filter()
        .userIdEqualTo(uid) // [關鍵] 別人的課不會影響我的衝突檢查
        .semesterEqualTo(newCourse.semester)
        .dayOfWeekEqualTo(newCourse.dayOfWeek)
        .findAll();

    // 2. 逐一比對時間
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
    await isar.writeTxn(() async {
      await isar.courses.delete(id);
    });
  }

  // [新增] 取得該使用者「所有學期」的課程 (用於統計)
  Future<List<Course>> getAllCoursesByUser() async {
    final isar = await db;
    final uid = currentUserId;

    if (uid == null) return [];

    return await isar.courses
        .filter()
        .userIdEqualTo(uid)
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