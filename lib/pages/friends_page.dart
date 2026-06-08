import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/friend.dart';
import '../services/friend_service.dart';
import 'friend_schedule_page.dart';

class FriendsPage extends StatefulWidget {
  final String currentSemester;
  const FriendsPage({super.key, required this.currentSemester});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _friendService = FriendService();
  final _uidController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? "未知";

  void _addFriend() async {
    final uid = _uidController.text.trim();
    final name = _nameController.text.trim();
    if (uid.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('代碼與暱稱都必須填寫')));
      return;
    }

    setState(() => _isLoading = true);
    final result = await _friendService.addFriend(uid, name);
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
      if (result == "好友已加入！") {
        _uidController.clear();
        _nameController.clear();
      }
    }
  }

  void _copyMyUid() {
    Clipboard.setData(ClipboardData(text: _myUid));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('專屬代碼已複製到剪貼簿')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的好友'),
      ),
      body: Column(
        children: [
          // 我的代碼區塊
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.blue.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.qr_code, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('我的專屬代碼 (分享給朋友來加您)：', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(_myUid, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.blue),
                  onPressed: _copyMyUid,
                  tooltip: '複製代碼',
                )
              ],
            ),
          ),
          
          // 新增好友區塊
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _uidController,
                  decoration: const InputDecoration(
                    labelText: '貼上好友的專屬代碼',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.key),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '自訂好友暱稱',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _addFriend,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('加入'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          // 好友列表區塊
          Expanded(
            child: StreamBuilder<List<Friend>>(
              stream: _friendService.getFriendsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('載入好友失敗'));
                }
                
                final friends = snapshot.data ?? [];
                if (friends.isEmpty) {
                  return const Center(child: Text('目前還沒有好友'));
                }

                return ListView.separated(
                  itemCount: friends.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final f = friends[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.withOpacity(0.2),
                        child: Text(f.name[0].toUpperCase(), style: const TextStyle(color: Colors.blue)),
                      ),
                      title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('代碼: ${f.friendUid}', style: const TextStyle(fontSize: 10)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.grey),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('刪除好友'),
                              content: Text('確定要刪除 ${f.name} 嗎？'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                                TextButton(
                                  onPressed: () {
                                    _friendService.removeFriend(f.id);
                                    Navigator.pop(ctx);
                                  }, 
                                  child: const Text('確定', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            )
                          );
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FriendSchedulePage(
                              friendUid: f.friendUid,
                              friendName: f.name,
                              currentSemester: widget.currentSemester,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
