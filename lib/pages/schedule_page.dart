import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/course_service.dart';
import 'course_edit_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'stats_page.dart';
import 'settings_page.dart'; // [新增]
import 'package:provider/provider.dart'; // [缺這行] 才能用 Provider.of
import '../providers/settings_provider.dart'; // [缺這行] 才能辨識 SettingsProvider 類別

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final _service = CourseService();
  List<Course> _courses = [];

  // [修改] 不再寫死 '112-1'，而是設為空字串，稍後在 initState 計算
  late String _currentSemester;
  List<String> _semesterOptions = [];

  // --- 介面常數設定 ---
  final double _headerHeight = 40.0;    // 星期幾那列的高度
  final double _timeColumnWidth = 50.0; // 左邊時間欄的寬度
  final double _periodHeight = 60.0;    // 每一節課的高度
  final int _totalDays = 7;             // 顯示幾天 (週一到週日)

  @override
  void initState() {
    super.initState();

    // 1. 先算出預設的當前學期 (確保畫面有東西顯示)
    _currentSemester = _getAutoCurrentSemester();

    // 2. 執行「合併選單」的邏輯
    _initSemesterOptions();

    _loadCourses();
  }

  // [修改] 初始化學期選單：連續性補齊邏輯
  Future<void> _initSemesterOptions() async {
    // 1. 取得當前年份 (例如: 2028 -> 民國 117)
    final now = DateTime.now();
    int currentRocYear = now.year - 1911;

    // 2. 設定「預設」的起點與終點
    // 規則：前 2 年 ~ 後 1 年
    int startYear = currentRocYear - 2; // 預設起點 (例如 115)
    int endYear = currentRocYear + 1;   // 預設終點 (例如 118)

    // 3. 檢查資料庫中最舊的資料
    List<String> dbSemesters = await _service.getUsedSemesters();
    if (dbSemesters.isNotEmpty) {
      // 解析資料庫裡的學期，找出最小年份
      // 例如 ["113-1", "116-2"] -> 找出 113
      int minDbYear = dbSemesters
          .map((s) => int.tryParse(s.split('-')[0]) ?? currentRocYear)
          .reduce((min, val) => val < min ? val : min); // 找出最小值

      // 4. [關鍵邏輯] 如果資料庫的年份更早，就把起點往前拉
      if (minDbYear < startYear) {
        startYear = minDbYear;
      }
    }

    // 5. 產生連續的列表 (填補中間的空缺)
    List<String> finalList = [];
    for (int year = startYear; year <= endYear; year++) {
      finalList.add('$year-1');
      finalList.add('$year-2');
    }

    // 6. 更新 UI
    if (mounted) {
      setState(() {
        _semesterOptions = finalList;

        // 防呆：確保當前學期一定有被選到 (理論上上面的邏輯已經涵蓋了)
        if (!_semesterOptions.contains(_currentSemester)) {
          _semesterOptions.add(_currentSemester);
          _semesterOptions.sort(); // 重新排序
        }
      });
    }
  }

  // [新增] 根據現在時間，自動判斷學期
  String _getAutoCurrentSemester() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    // 民國年換算
    int rocYear = year - 1911;

    // 依照你的規則：6-12月是上學期，1-5月是下學期
    if (month >= 6) {
      // 2025年 6月 -> 114-1
      return '$rocYear-1';
    } else {
      // 2026年 1月 -> 114-2 (其實是 115年的年初，但算在 114學年度)
      return '${rocYear - 1}-2';
    }
  }

  Future<void> _loadCourses() async {
    final courses = await _service.getCoursesBySemester(_currentSemester);
    setState(() {
      _courses = courses;
    });
  }

  // 開啟編輯頁面
  void _openEditPage([Course? course]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CourseEditPage(
          course: course,
          // [新增] 這裡！如果是新增課程 (course == null)，就把當前學期傳過去
          initialSemester: course == null ? _currentSemester : null,
        ),
      ),
    );
    if (result == true) _loadCourses();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的課表'),
        actions: [
          // 學期切換 Dropdown
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _currentSemester,
              style: const TextStyle(color: Colors.black, fontSize: 16),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
              items: _semesterOptions
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _currentSemester = val);
                  _loadCourses();
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
          ),
          // [新增] 成績圖表按鈕
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: '成績分析',
            onPressed: () {
              // 跳轉到統計頁面
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StatsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout), // [新增] 登出按鈕
            onPressed: () {
              FirebaseAuth.instance.signOut(); // 執行登出
              // AuthGate 會監聽到狀態改變，自動跳回登入頁
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 動態計算每一天的寬度： (螢幕總寬 - 時間欄寬) / 7天
          final double dayWidth = (constraints.maxWidth - _timeColumnWidth) / _totalDays;

          return Column(
            children: [
              // 1. 頂部星期幾 Header (固定不動)
              SizedBox(
                height: _headerHeight,
                child: Row(
                  children: [
                    SizedBox(width: _timeColumnWidth), // 左上角留空
                    ...List.generate(_totalDays, (index) {
                      final dayNames = ['一', '二', '三', '四', '五', '六', '日'];
                      return SizedBox(
                        width: dayWidth,
                        child: Center(
                          child: Text(
                            dayNames[index],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),

              // 2. 可捲動的課表區塊
              Expanded(
                child: SingleChildScrollView(
                  child: SizedBox(
                    // [修改] 總高度使用 settings.maxPeriods
                    height: _periodHeight * settings.maxPeriods,
                    child: Stack(
                      children: [
                        // A. 畫背景格線 & 時間欄
                        ...List.generate(settings.maxPeriods, (index) {
                          final period = index + 1;
                          final top = index * _periodHeight;
                          return Positioned(
                            top: top,
                            left: 0,
                            right: 0,
                            height: _periodHeight,
                            child: Row(
                              children: [
                                // 左側時間
                                SizedBox(
                                  width: _timeColumnWidth,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(period.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      // [修改] 時間顯示改用 settings 計算
                                      Text(
                                        settings.getPeriodStartTime(period),
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                // 橫線與格線
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(color: Colors.grey[200]!),
                                        left: BorderSide(color: Colors.grey[200]!),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        // B. 畫直向分隔線 (讓格子更明顯)
                        ...List.generate(_totalDays, (index) {
                          return Positioned(
                            left: _timeColumnWidth + (index * dayWidth),
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 1,
                              color: Colors.grey[200],
                            ),
                          );
                        }),

                        // C. 課程區塊
                        ..._courses.map((course) {
                          // [防呆] 如果課程節次超過目前設定的最大節次，就不顯示 (或是顯示但不完整)
                          if (course.startPeriod > settings.maxPeriods) return const SizedBox();

                          // 座標計算保持不變
                          final double left = _timeColumnWidth + (course.dayOfWeek - 1) * dayWidth;
                          final double top = (course.startPeriod - 1) * _periodHeight;

                          // [修正] 如果課程結束節次超過設定值，將高度截斷，避免超出邊界
                          int effectiveEnd = course.endPeriod;
                          if (effectiveEnd > settings.maxPeriods) effectiveEnd = settings.maxPeriods;

                          final double height = (effectiveEnd - course.startPeriod + 1) * _periodHeight;

                          // 稍微留一點邊距 (padding)，不要黏在一起
                          return Positioned(
                            left: left + 1,
                            top: top + 1,
                            width: dayWidth - 2,
                            height: height - 2,
                            child: GestureDetector(
                              onTap: () => _openEditPage(course),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Color(course.colorHex).withOpacity(0.9), // 用戶設定的顏色
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                padding: const EdgeInsets.all(2),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      course.courseName,
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (course.classroom != null && course.classroom!.isNotEmpty)
                                      Text(
                                        course.classroom!,
                                        style: const TextStyle(color: Colors.white70, fontSize: 9),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditPage(),
        child: const Icon(Icons.add),
      ),
    );
  }
}