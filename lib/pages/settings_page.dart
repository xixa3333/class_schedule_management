import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 取得設定狀態
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          // 1. 深色模式設定
          _buildSectionHeader('外觀'),
          RadioListTile<ThemeMode>(
            title: const Text('跟隨系統'),
            value: ThemeMode.system,
            groupValue: settings.themeMode,
            onChanged: (val) => settings.setThemeMode(val!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('淺色模式'),
            value: ThemeMode.light,
            groupValue: settings.themeMode,
            onChanged: (val) => settings.setThemeMode(val!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('深色模式'),
            value: ThemeMode.dark,
            groupValue: settings.themeMode,
            onChanged: (val) => settings.setThemeMode(val!),
          ),

          const Divider(),

          // 2. 課表顯示設定
          _buildSectionHeader('課表顯示'),
          ListTile(
            title: const Text('最大節次數'),
            subtitle: Text('目前顯示：${settings.maxPeriods} 節'),
            trailing: DropdownButton<int>(
              value: settings.maxPeriods,
              underline: Container(),
              items: List.generate(6, (index) => 10 + index) // 產生 10~15
                  .map((e) => DropdownMenuItem(value: e, child: Text('$e 節')))
                  .toList(),
              onChanged: (val) {
                if (val != null) settings.setMaxPeriods(val);
              },
            ),
          ),

          const Divider(),

          // 3. 時間設定
          _buildSectionHeader('上課時間'),
          ListTile(
            title: const Text('第 1 節開始時間'),
            subtitle: Text(settings.morningStartTime),
            trailing: const Icon(Icons.access_time),
            onTap: () => _pickTime(context, settings, true),
          ),
          ListTile(
            title: const Text('第 5 節 (下午) 開始時間'),
            subtitle: Text(settings.afternoonStartTime),
            trailing: const Icon(Icons.access_time),
            onTap: () => _pickTime(context, settings, false),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  // 時間選擇器
  Future<void> _pickTime(BuildContext context, SettingsProvider settings, bool isMorning) async {
    // 解析目前的時間字串
    final currentStr = isMorning ? settings.morningStartTime : settings.afternoonStartTime;
    final parts = currentStr.split(':');
    final initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      if (isMorning) {
        settings.setMorningStartTime(picked.hour, picked.minute);
      } else {
        settings.setAfternoonStartTime(picked.hour, picked.minute);
      }
    }
  }
}