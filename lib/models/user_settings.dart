import 'package:isar/isar.dart';

part 'user_settings.g.dart';

@collection
class UserSettings {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value, unique: true, replace: true)
  String? userId; // 綁定 Firebase UID

  int maxPeriods = 13; // 最大節次

  // 早上開始時間
  int morningStartHour = 8;
  int morningStartMinute = 10;

  // 下午開始時間
  int afternoonStartHour = 13;
  int afternoonStartMinute = 30;

  // 主題模式 (0: System, 1: Light, 2: Dark)
  int themeModeIndex = 0;
}