import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:isar/isar.dart';
import '../models/course.dart';

class WidgetService {
  static const String iOSGroupId = 'group.com.example.classScheduleManagement';
  static const String widgetDataKey = 'today_courses';

  static Future<void> updateWidgetData(Isar isar) async {
    try {
      final int today = DateTime.now().weekday;

      final todayCourses = await isar.courses
          .filter()
          .dayOfWeekEqualTo(today)
          .sortByStartPeriod()
          .findAll();

      final List<Map<String, dynamic>> jsonList =
      todayCourses.map((course) => course.toJson()).toList();
      final String jsonData = jsonEncode(jsonList);

      await HomeWidget.setAppGroupId(iOSGroupId);
      await HomeWidget.saveWidgetData(widgetDataKey, jsonData);

      await HomeWidget.updateWidget(
        iOSName: 'CourseWidget',
        androidName: 'CourseWidgetReceiver',
      );
      debugPrint('✅ 成功同步今日課表至桌面 Widget: $jsonData');
    } catch (e) {
      debugPrint('❌ 同步 Widget 資料失敗: $e');
    }
  }
}