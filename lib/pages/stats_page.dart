import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/course_service.dart';
import '../utils/grade_helper.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final _service = CourseService();

  // --- 圖表數據 ---
  List<FlSpot> _gpaSpots = [];   // GPA 趨勢點
  List<FlSpot> _scoreSpots = []; // 平均分數 趨勢點
  List<String> _semesterLabels = []; // X軸標籤 (112-1, 112-2...)

  // --- 總覽數據 ---
  double _totalEarnedCredits = 0; // 總實得學分 (>=60分)
  double _totalAvgScore = 0;      // 總平均分數
  double _totalAvgGpa = 0;        // 總平均 GPA

  // --- 介面控制 ---
  bool _showGpaChart = true; // true顯示GPA圖, false顯示分數圖

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  Future<void> _calculateStats() async {
    final allCourses = await _service.getAllCoursesByUser();

    // 1. 依照學期分組
    Map<String, List<Map<String, dynamic>>> semesterMap = {};

    // 2. 全域累計變數 (用來算總平均)
    double grandTotalWeightedScore = 0; // 累計 (分數 * 學分)
    double grandTotalWeightedGpa = 0;   // 累計 (GPA * 學分)
    double grandTotalValidCredits = 0;  // 累計「有填成績」的總學分 (分母)
    double grandTotalEarnedCredits = 0; // 累計「及格」的總學分 (>=60)

    for (var course in allCourses) {
      // 排除條件：沒學分 或 沒成績
      if (course.credits <= 0 || course.score == null) continue;

      double score = course.score!;
      double credits = course.credits;
      double gpa = GradeHelper.scoreToGpa(score);

      // 分組
      if (!semesterMap.containsKey(course.semester)) {
        semesterMap[course.semester] = [];
      }
      semesterMap[course.semester]!.add({
        'score': score,
        'credits': credits,
        'gpa': gpa,
      });

      // 計算總累計
      grandTotalWeightedScore += score * credits;
      grandTotalWeightedGpa += gpa * credits;
      grandTotalValidCredits += credits;

      // 計算實得學分 (及格才算)
      if (score >= 60) {
        grandTotalEarnedCredits += credits;
      }
    }

    // 3. 計算每學期的平均
    List<FlSpot> gpaSpots = [];
    List<FlSpot> scoreSpots = [];
    List<String> labels = [];

    var sortedKeys = semesterMap.keys.toList()..sort();

    for (int i = 0; i < sortedKeys.length; i++) {
      String semester = sortedKeys[i];
      var courses = semesterMap[semester]!;

      double semTotalWeightedScore = 0;
      double semTotalWeightedGpa = 0;
      double semTotalCredits = 0;

      for (var c in courses) {
        semTotalWeightedScore += c['score'] * c['credits'];
        semTotalWeightedGpa += c['gpa'] * c['credits'];
        semTotalCredits += c['credits'];
      }

      // 避免除以 0
      double semAvgScore = semTotalCredits == 0 ? 0 : semTotalWeightedScore / semTotalCredits;
      double semAvgGpa = semTotalCredits == 0 ? 0 : semTotalWeightedGpa / semTotalCredits;

      // 格式化小數點後兩位
      semAvgScore = double.parse(semAvgScore.toStringAsFixed(2));
      semAvgGpa = double.parse(semAvgGpa.toStringAsFixed(2));

      // 加入圖表數據 (X軸是 index)
      gpaSpots.add(FlSpot(i.toDouble(), semAvgGpa));
      scoreSpots.add(FlSpot(i.toDouble(), semAvgScore));
      labels.add(semester);
    }

    // 4. 計算總平均
    double finalAvgScore = grandTotalValidCredits == 0 ? 0 : grandTotalWeightedScore / grandTotalValidCredits;
    double finalAvgGpa = grandTotalValidCredits == 0 ? 0 : grandTotalWeightedGpa / grandTotalValidCredits;

    if (mounted) {
      setState(() {
        _gpaSpots = gpaSpots;
        _scoreSpots = scoreSpots;
        _semesterLabels = labels;

        _totalEarnedCredits = grandTotalEarnedCredits;
        _totalAvgScore = double.parse(finalAvgScore.toStringAsFixed(2));
        _totalAvgGpa = double.parse(finalAvgGpa.toStringAsFixed(2));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('成績分析')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. 總覽卡片區 (使用 Row + Expanded 平均分配)
            Row(
              children: [
                _buildInfoCard('總實得學分', '$_totalEarnedCredits', Colors.blue, subtitle: '(>=60分)'),
                const SizedBox(width: 8),
                _buildInfoCard('總平均分數', '$_totalAvgScore', Colors.orange),
                const SizedBox(width: 8),
                _buildInfoCard('總平均 GPA', '$_totalAvgGpa', Colors.green),
              ],
            ),

            const SizedBox(height: 30),

            // 2. 圖表切換按鈕
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTabButton('GPA 趨勢', true),
                  _buildTabButton('平均分數趨勢', false),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 3. 折線圖
            SizedBox(
              height: 300,
              child: _semesterLabels.isEmpty
                  ? const Center(child: Text('目前沒有成績資料，請先至課表新增。'))
                  : LineChart(
                _showGpaChart ? _buildGpaChart() : _buildScoreChart(),
              ),
            ),

            const SizedBox(height: 10),
            Text(
              _showGpaChart ? '* GPA 最高 4.3 (NTU 標準)' : '* 平均分數滿分 100',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),

            const SizedBox(height: 20),

            // 4. 詳細數據列表 (選用，讓使用者直接看數字)
            if (_semesterLabels.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('各學期詳細數據', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _semesterLabels.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(_semesterLabels[index], style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('GPA: ${_gpaSpots[index].y}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              Text('平均: ${_scoreSpots[index].y}', style: const TextStyle(color: Colors.orange)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- UI 元件構建 helper ---

  Widget _buildTabButton(String text, bool isGpa) {
    bool isSelected = _showGpaChart == isGpa;
    return GestureDetector(
      onTap: () => setState(() => _showGpaChart = isGpa),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : [],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.black : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, Color color, {String? subtitle}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            FittedBox(child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold))),
            if (subtitle != null)
              Text(subtitle, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
            const SizedBox(height: 8),
            FittedBox(child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color))),
          ],
        ),
      ),
    );
  }

  // 建構 GPA 圖表設定
  LineChartData _buildGpaChart() {
    return LineChartData(
      minY: 0,
      maxY: 4.5,
      gridData: const FlGridData(show: true),
      titlesData: _buildTitles(),
      borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey[300]!)),
      lineBarsData: [
        LineChartBarData(
          spots: _gpaSpots,
          isCurved: false,
          color: Colors.green,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.1)),
        ),
      ],
    );
  }

  // 建構 分數 圖表設定
  LineChartData _buildScoreChart() {
    // 動態計算 Y 軸最大最小值，讓折線比較明顯
    double minY = 0;
    if (_scoreSpots.isNotEmpty) {
      // 找出最低分，減去 10 分當底，但不能小於 0
      double minScore = _scoreSpots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
      minY = (minScore - 10).clamp(0, 100);
    }

    return LineChartData(
      minY: minY,
      maxY: 100, // 分數滿分 100
      gridData: const FlGridData(show: true),
      titlesData: _buildTitles(),
      borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey[300]!)),
      lineBarsData: [
        LineChartBarData(
          spots: _scoreSpots,
          isCurved: false,
          color: Colors.orange,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: true, color: Colors.orange.withOpacity(0.1)),
        ),
      ],
    );
  }

  FlTitlesData _buildTitles() {
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            int index = value.toInt();
            if (index >= 0 && index < _semesterLabels.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(_semesterLabels[index], style: const TextStyle(fontSize: 10)),
              );
            }
            return const Text('');
          },
          interval: 1,
        ),
      ),
      leftTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: true, reservedSize: 35),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }
}