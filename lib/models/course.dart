import 'package:isar/isar.dart';

part 'course.g.dart';

@collection
class Course {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  String? userId;

  @Index(type: IndexType.value)
  late String semester;

  late String courseName;
  String? classroom;
  String? teacher;

  late int dayOfWeek;
  late int startPeriod;
  late int endPeriod;

  int colorHex = 0xFF2196F3;
  String? note;

  bool enableNotification = true;

  double credits = 0.0;
  double? score;

  // 🌟 [新增] 雲端同步專用欄位
  @Index()
  bool isSynced = true; // 是否已同步至雲端 (預設 true，只有本地修改時才變 false)

  int updatedAt = 0; // 最後修改時間戳記 (毫秒)

  @Index()
  bool isDeleted = false; // 軟刪除標記

  String get periodString => '第 $startPeriod - $endPeriod 節';

  Map<String, dynamic> toJson() {
    return {
      'courseName': courseName,
      'classroom': classroom ?? '未安排',
      'startPeriod': startPeriod,
      'endPeriod': endPeriod,
      'periodString': periodString,
      'colorHex': colorHex.toRadixString(16).padLeft(8, '0'),
    };
  }

  // 🌟 [新增] 轉成 Firestore 支援的 Map
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'semester': semester,
      'courseName': courseName,
      'classroom': classroom,
      'teacher': teacher,
      'dayOfWeek': dayOfWeek,
      'startPeriod': startPeriod,
      'endPeriod': endPeriod,
      'colorHex': colorHex,
      'note': note,
      'enableNotification': enableNotification,
      'credits': credits,
      'score': score,
      'updatedAt': updatedAt,
      'isDeleted': isDeleted,
    };
  }
}