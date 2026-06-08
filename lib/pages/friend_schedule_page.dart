import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../services/course_service.dart';
import '../providers/settings_provider.dart';

class FriendSchedulePage extends StatefulWidget {
  final String friendUid;
  final String friendName;
  final String currentSemester;

  const FriendSchedulePage({
    super.key,
    required this.friendUid,
    required this.friendName,
    required this.currentSemester,
  });

  @override
  State<FriendSchedulePage> createState() => _FriendSchedulePageState();
}

class _FriendSchedulePageState extends State<FriendSchedulePage> {
  final _courseService = CourseService();
  List<Course> _myCourses = [];
  List<Course> _friendCourses = [];
  bool _isLoading = true;

  final double _headerHeight = 40.0;
  final double _timeColumnWidth = 50.0;
  final double _periodHeight = 60.0;
  final int _totalDays = 7;

  @override
  void initState() {
    super.initState();
    _loadAllCourses();
  }

  Future<void> _loadAllCourses() async {
    setState(() => _isLoading = true);

    try {
      // 1. 載入自己的課表 (本地端)
      _myCourses = await _courseService.getCoursesBySemester(widget.currentSemester);

      // 2. 載入好友的課表 (雲端)
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.friendUid)
          .collection('courses')
          .where('semester', isEqualTo: widget.currentSemester)
          .where('isDeleted', isEqualTo: false)
          .get();

      _friendCourses = snapshot.docs.map((doc) {
        final data = doc.data();
        return Course()
          ..id = int.tryParse(doc.id) ?? 0
          ..userId = data['userId']
          ..semester = data['semester']
          ..courseName = data['courseName']
          ..classroom = data['classroom']
          ..dayOfWeek = data['dayOfWeek']
          ..startPeriod = data['startPeriod']
          ..endPeriod = data['endPeriod']
          ..colorHex = data['colorHex'] ?? 0xFF9E9E9E; // 預設灰色
      }).toList();
    } catch (e) {
      print('載入課表失敗: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // 判斷某個時段 (dayOfWeek, period) 的狀態
  // 0 = 雙方皆空, 1 = 只有我有課, 2 = 只有好友有課, 3 = 雙方皆有課
  int _checkPeriodStatus(int dayOfWeek, int period) {
    bool iHaveClass = _myCourses.any((c) => c.dayOfWeek == dayOfWeek && period >= c.startPeriod && period <= c.endPeriod);
    bool friendHasClass = _friendCourses.any((c) => c.dayOfWeek == dayOfWeek && period >= c.startPeriod && period <= c.endPeriod);

    if (iHaveClass && friendHasClass) return 3;
    if (iHaveClass) return 1;
    if (friendHasClass) return 2;
    return 0; // 共同空堂
  }

  // 取得該格子的 UI 區塊 (為了簡化，這裡採用 1 節 1 格的繪製方式)
  Widget _buildCourseBlock(int dayOfWeek, int period, double width, double height) {
    final status = _checkPeriodStatus(dayOfWeek, period);

    if (status == 0) {
      // 共同空堂，不畫東西，底色為透明
      return const SizedBox();
    }

    Color bgColor;
    String text;
    Color textColor = Colors.white;

    if (status == 3) {
      bgColor = Colors.red.withOpacity(0.8);
      text = '雙方有課';
    } else if (status == 1) {
      // 找出自己的課來拿顏色 (若多堂重疊則取第一堂)
      final myCourse = _myCourses.firstWhere((c) => c.dayOfWeek == dayOfWeek && period >= c.startPeriod && period <= c.endPeriod);
      bgColor = Color(myCourse.colorHex).withOpacity(0.9);
      text = myCourse.courseName;
    } else {
      // 好友有課
      bgColor = Colors.grey.withOpacity(0.7);
      text = '好友有課';
    }

    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.all(1.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(2),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.friendName} 的課表'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // 圖例說明
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLegendItem('我的課', Colors.blue),
                    _buildLegendItem('好友的課', Colors.grey),
                    _buildLegendItem('共同衝堂', Colors.red),
                    _buildLegendItem('共同空堂', Colors.transparent, isBordered: true),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),
              
              // 課表區塊
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double dayWidth = (constraints.maxWidth - _timeColumnWidth) / _totalDays;

                    return Column(
                      children: [
                        // 1. 頂部星期幾 Header
                        SizedBox(
                          height: _headerHeight,
                          child: Row(
                            children: [
                              SizedBox(width: _timeColumnWidth),
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

                        // 2. 網格內容
                        Expanded(
                          child: SingleChildScrollView(
                            child: SizedBox(
                              height: _periodHeight * settings.maxPeriods,
                              child: Stack(
                                children: [
                                  // 畫格線 & 時間欄
                                  ...List.generate(settings.maxPeriods, (index) {
                                    final period = index + 1;
                                    return Positioned(
                                      top: index * _periodHeight,
                                      left: 0,
                                      right: 0,
                                      height: _periodHeight,
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: _timeColumnWidth,
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(period.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                                Text(
                                                  settings.getPeriodStartTime(period),
                                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                          ),
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

                                  // 直向分隔線
                                  ...List.generate(_totalDays, (index) {
                                    return Positioned(
                                      left: _timeColumnWidth + (index * dayWidth),
                                      top: 0,
                                      bottom: 0,
                                      child: Container(width: 1, color: Colors.grey[200]),
                                    );
                                  }),

                                  // 逐格畫課程 (簡化版：一節一節畫)
                                  ...List.generate(settings.maxPeriods * _totalDays, (index) {
                                    final period = (index / _totalDays).floor() + 1;
                                    final dayOfWeek = (index % _totalDays) + 1;
                                    
                                    final double left = _timeColumnWidth + (dayOfWeek - 1) * dayWidth;
                                    final double top = (period - 1) * _periodHeight;

                                    return Positioned(
                                      left: left,
                                      top: top,
                                      width: dayWidth,
                                      height: _periodHeight,
                                      child: _buildCourseBlock(dayOfWeek, period, dayWidth, _periodHeight),
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
              ),
            ],
          ),
    );
  }

  Widget _buildLegendItem(String text, Color color, {bool isBordered = false}) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: isBordered ? Border.all(color: Colors.grey) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
