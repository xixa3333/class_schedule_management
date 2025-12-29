import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/course.dart';
import '../services/course_service.dart';

class CourseEditPage extends StatefulWidget {
  final Course? course; // 如果是 null 代表是「新增」，有值代表是「修改」
  final String? initialSemester; // [新增] 用來接收外部傳入的預設學期

  const CourseEditPage({super.key, this.course, this.initialSemester});

  @override
  State<CourseEditPage> createState() => _CourseEditPageState();
}

class _CourseEditPageState extends State<CourseEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = CourseService();

  // 表單控制器
  final _nameCtrl = TextEditingController();
  final _teacherCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _creditsCtrl = TextEditingController();
  final _scoreCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  late String _selectedSemester; // [修改] 改成 late，因為要動態決定
  late List<String> _semesterOptions; // [新增] 動態學期列表

  // 預設值
  int _dayOfWeek = 1;      // 週一
  int _startPeriod = 1;    // 第1節
  int _endPeriod = 2;      // 第2節
  Color _currentColor = Colors.blue;

  @override
  void initState() {
    super.initState();

    // 1. 決定 _selectedSemester 的預設值
    if (widget.course != null) {
      // 如果是編輯舊課程，用舊資料的學期
      _selectedSemester = widget.course!.semester;
    } else {
      // 如果是新增，優先使用傳入的 initialSemester，沒有的話就給個預設值
      _selectedSemester = widget.initialSemester ?? '112-1';
    }

    // 2. [新增] 動態產生學期選單 (避免傳入的學期不在硬編碼的清單中導致 Crash)
    _semesterOptions = _generateSemesterList(_selectedSemester);

    // 3. 填入其他舊資料 (如果是編輯模式)
    if (widget.course != null) {
      final c = widget.course!;
      _nameCtrl.text = c.courseName;
      _teacherCtrl.text = c.teacher ?? '';
      _roomCtrl.text = c.classroom ?? '';
      _creditsCtrl.text = c.credits.toString();
      _scoreCtrl.text = c.score?.toString() ?? '';
      _noteCtrl.text = c.note ?? '';

      _dayOfWeek = c.dayOfWeek;
      _startPeriod = c.startPeriod;
      _endPeriod = c.endPeriod;
      _currentColor = Color(c.colorHex);
    }
  }

  // [新增] 產生學期列表的邏輯 (跟 SchedulePage 一樣)
  List<String> _generateSemesterList(String current) {
    int baseYear = int.tryParse(current.split('-')[0]) ?? 112;
    List<String> list = [];
    // 產生範圍：前後 2 年，確保選單夠多
    for (int y = baseYear - 2; y <= baseYear + 2; y++) {
      list.add('$y-1');
      list.add('$y-2');
    }
    return list;
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      // 1. 先把資料填入物件 (但還沒存進資料庫)
      final newCourse = widget.course ?? Course();

      // 注意：這裡必須先賦值，才能拿去檢查衝突
      newCourse.courseName = _nameCtrl.text;
      newCourse.teacher = _teacherCtrl.text;
      newCourse.classroom = _roomCtrl.text;
      newCourse.semester = _selectedSemester;
      newCourse.dayOfWeek = _dayOfWeek;
      newCourse.startPeriod = _startPeriod;
      newCourse.endPeriod = _endPeriod;
      newCourse.colorHex = _currentColor.value;
      newCourse.credits = double.tryParse(_creditsCtrl.text) ?? 0.0;
      newCourse.score = double.tryParse(_scoreCtrl.text);
      newCourse.note = _noteCtrl.text;

      // [新增] 2. 檢查是否有時間衝突
      // 如果開始節次 > 結束節次，也是不合法的
      if (newCourse.startPeriod > newCourse.endPeriod) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('錯誤：開始節次不能晚於結束節次')),
        );
        return;
      }

      final hasConflict = await _service.isTimeConflict(newCourse);
      if (hasConflict) {
        // 發現衝突，跳出警告並「中斷」儲存
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('課程衝突'),
              content: const Text('該時段已經有其他課程了，請檢查時間。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('確定'),
                ),
              ],
            ),
          );
        }
        return; // <--- 這裡很重要，直接結束，不執行 saveCourse
      }

      // 3. 通過檢查，正式寫入資料庫
      await _service.saveCourse(newCourse);

      if (mounted) Navigator.pop(context, true);
    }
  }

  // [新增] 刪除確認與執行
  void _delete() async {
    if (widget.course == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除課程'),
        content: Text('確定要刪除「${widget.course!.courseName}」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.deleteCourse(widget.course!.id);
      if (mounted) Navigator.pop(context, true); // 回傳 true 代表有變動
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course == null ? '新增課程' : '編輯課程'),
        actions: [
          // [新增] 只有在「編輯舊課程」時才顯示刪除按鈕
          if (widget.course != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _delete, // 點擊觸發刪除
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // [修改] 學期下拉選單
            DropdownButtonFormField<String>(
              value: _selectedSemester,
              decoration: const InputDecoration(labelText: '學期'),
              // 使用動態生成的列表
              items: _semesterOptions
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedSemester = v!),
            ),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '課程名稱'),
              validator: (v) => v!.isEmpty ? '請輸入名稱' : null,
            ),

            // [新增] 老師姓名輸入框 (加在這裡)
            const SizedBox(height: 10),
            TextFormField(
              controller: _teacherCtrl,
              decoration: const InputDecoration(
                labelText: '授課老師',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 10),

            // [新增] 教室輸入框 (之前可能也漏了，順便補上比較完整)
            TextFormField(
              controller: _roomCtrl,
              decoration: const InputDecoration(
                labelText: '教室地點',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),

            const SizedBox(height: 20),

            // 2. 時間選擇 (簡單版：使用 Dropdown)
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _dayOfWeek,
                    decoration: const InputDecoration(labelText: '星期'),
                    items: List.generate(7, (i) =>
                        DropdownMenuItem(value: i + 1, child: Text('週${_getDayName(i + 1)}'))
                    ),
                    onChanged: (v) => setState(() => _dayOfWeek = v!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _startPeriod,
                    decoration: const InputDecoration(labelText: '開始節'),
                    items: List.generate(14, (i) =>
                        DropdownMenuItem(value: i + 1, child: Text('第${i + 1}節'))
                    ),
                    onChanged: (v) => setState(() => _startPeriod = v!),
                  ),
                ),
                const Text(" 至 "),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _endPeriod,
                    decoration: const InputDecoration(labelText: '結束節'),
                    items: List.generate(14, (i) =>
                        DropdownMenuItem(value: i + 1, child: Text('第${i + 1}節'))
                    ),
                    onChanged: (v) => setState(() => _endPeriod = v!),
                  ),
                ),
              ],
            ),

            // 3. 成績與學分
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _creditsCtrl,
                    decoration: const InputDecoration(labelText: '學分'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _scoreCtrl,
                    decoration: const InputDecoration(labelText: '成績 (選填)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 4. 顏色選擇
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('課程顏色'),
              subtitle: Text('設定在課表上顯示的顏色'),
              trailing: GestureDetector(
                onTap: _showColorPicker, // 點擊觸發選擇器
                child: CircleAvatar(
                  backgroundColor: _currentColor,
                  radius: 20,
                  // 加個白色邊框比較好看
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey, width: 1),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // [新增] 備註欄位
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: '備註',
                hintText: '例如：單週上課、期中考日期...',
                border: OutlineInputBorder(), // 加個邊框比較像備註區
                alignLabelWithHint: true,
              ),
              maxLines: 3, // 讓它可以輸入多行
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('儲存課程', style: TextStyle(fontSize: 18)),
              ),
            ),

            const SizedBox(height: 30), // 底部留白
          ],
        ),
      ),
    );
  }

  // [新增] 顯示顏色選擇器的函式
  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('選擇課程顏色'),
          content: SingleChildScrollView(
            child: BlockPicker( // 使用 BlockPicker (色塊選擇) 比較適合課表
              pickerColor: _currentColor,
              onColorChanged: (color) {
                setState(() => _currentColor = color);
                Navigator.of(context).pop(); // 選完自動關閉
              },
            ),
          ),
        );
      },
    );
  }

  String _getDayName(int day) {
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    return days[day - 1];
  }

}