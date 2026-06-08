import '../models/user_settings.dart';

class TimeHelper {
  // 改為接收 UserSettings，從設定中取得起始時間
  static String getStartTime(int period, UserSettings settings) {
    int startHour;
    int startMinute;

    if (period <= 4) {
      // 使用 UserSettings 設定的早上起始時間
      startHour = settings.morningStartHour + (period - 1);
      startMinute = settings.morningStartMinute;
    } else {
      // 使用 UserSettings 設定的下午起始時間
      startHour = settings.afternoonStartHour + (period - 5);
      startMinute = settings.afternoonStartMinute;
    }

    return "${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}";
  }

// getEndTime 同理，也應改為接收 UserSettings 來計算
}