import 'package:isar/isar.dart';

part 'course.g.dart'; // 這一行會報錯是正常的，等下執行 build_runner 就會好

@collection
class Course {
  Id id = Isar.autoIncrement; // Isar 自動生成的整數 ID

  @Index(type: IndexType.value) // [新增] 加入索引，方便查詢
  String? userId; // [新增] 用來存 Firebase 的 UID

  @Index(type: IndexType.value)
  late String semester; // 學期代號，例如 "112-1", "112-2"

  late String courseName; // 課程名稱
  String? classroom;      // 教室
  String? teacher;        // 老師

  // 時間設定
  late int dayOfWeek;     // 星期幾 (1=週一, 7=週日)
  late int startPeriod;   // 開始節次 (例如: 1)
  late int endPeriod;     // 結束節次 (例如: 3)

  // 顏色與備註
  int colorHex = 0xFF2196F3; // 預設藍色 (存 int 格式)
  String? note;           // 備註

  // 成績相關
  double credits = 0.0;   // 學分
  double? score;          // 成績 (null 代表還沒出來)

  // 用來在 UI 顯示 "第 1-3 節"
  String get periodString => '第 $startPeriod - $endPeriod 節';
}