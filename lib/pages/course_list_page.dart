import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/course_service.dart';
import 'course_edit_page.dart';

class CourseListPage extends StatefulWidget {
  const CourseListPage({super.key});

  @override
  State<CourseListPage> createState() => _CourseListPageState();
}

class _CourseListPageState extends State<CourseListPage> {
  final _service = CourseService();
  List<Course> _courses = [];
  String _currentSemester = '112-1'; // 預設顯示的學期

  @override
  void initState() {
    super.initState();
    _loadCourses(); // 畫面一啟動就讀資料
  }

  // 從資料庫讀取課程
  Future<void> _loadCourses() async {
    final courses = await _service.getCoursesBySemester(_currentSemester);
    setState(() {
      _courses = courses;
    });
  }

  // 跳轉到編輯頁面 (新增或修改)
  void _openEditPage([Course? course]) async {
    // Navigator.push 會等待編輯頁面關閉後回傳 result
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CourseEditPage(course: course)),
    );

    // 如果回傳 true (代表有按儲存)，就重新讀取列表
    if (result == true) {
      _loadCourses();
    }
  }

  // 刪除課程
  void _deleteCourse(Course course) async {
    // 跳出確認視窗
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除課程'),
        content: Text('確定要刪除「${course.courseName}」嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('刪除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _service.deleteCourse(course.id);
      _loadCourses(); // 刪完重新讀取
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的課程紀錄'),
      ),
      body: Column(
        children: [
          // 1. 學期選擇器
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[200],
            child: Row(
              children: [
                const Text('選擇學期：', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _currentSemester,
                  underline: Container(), // 去掉底線
                  items: ['112-1', '112-2', '113-1', '113-2']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _currentSemester = val);
                      _loadCourses(); // 切換學期後重讀資料
                    }
                  },
                ),
              ],
            ),
          ),

          // 2. 課程列表
          Expanded(
            child: _courses.isEmpty
                ? const Center(child: Text('目前沒有課程，按右下角新增'))
                : ListView.builder(
              itemCount: _courses.length,
              itemBuilder: (context, index) {
                final course = _courses[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(course.colorHex),
                      child: Text(
                        course.courseName.isNotEmpty ? course.courseName[0] : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(course.courseName),
                    subtitle: Text(
                      '週${_getDayName(course.dayOfWeek)} ${course.periodString} | ${course.classroom ?? "無教室"}',
                    ),
                    trailing: Text('${course.credits} 學分'),
                    onTap: () => _openEditPage(course), // 點擊修改
                    onLongPress: () => _deleteCourse(course), // 長按刪除
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditPage(), // 點擊新增
        child: const Icon(Icons.add),
      ),
    );
  }

  String _getDayName(int day) {
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    // 防止索引超出範圍 (防呆)
    if (day < 1 || day > 7) return '?';
    return days[day - 1];
  }
}