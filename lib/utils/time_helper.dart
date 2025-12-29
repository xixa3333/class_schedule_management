class TimeHelper {
  /// 根據節次回傳「開始時間」字串
  static String getStartTime(int period) {
    int startHour;
    int startMinute;

    if (period <= 4) {
      // 早上：第一節 08:10 開始 (8點 + (period-1)小時)
      // 08:10, 09:10, 10:10, 11:10
      startHour = 8 + (period - 1);
      startMinute = 10;
    } else {
      // 下午：第五節 13:30 開始
      // P5=13:30, P6=14:30...
      // period - 5 代表下午的第幾堂
      startHour = 13 + (period - 5);
      startMinute = 30;
    }

    return "${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}";
  }

  /// 根據節次回傳「結束時間」字串 (每節 50 分鐘)
  static String getEndTime(int period) {
    int startHour;
    int startMinute;

    if (period <= 4) {
      startHour = 8 + (period - 1);
      startMinute = 10;
    } else {
      startHour = 13 + (period - 5);
      startMinute = 30;
    }

    // 加上 50 分鐘
    int endTotalMinutes = startHour * 60 + startMinute + 50;
    int endHour = endTotalMinutes ~/ 60;
    int endMinute = endTotalMinutes % 60;

    return "${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}";
  }
}