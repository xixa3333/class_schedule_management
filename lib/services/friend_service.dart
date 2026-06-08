import 'package:isar/isar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/friend.dart';
import 'course_service.dart';

class FriendService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CourseService _courseService = CourseService();

  String? get currentUserId => _auth.currentUser?.uid;

  // 取得好友列表 Stream (使用 Isar watch)
  Stream<List<Friend>> getFriendsStream() async* {
    final uid = currentUserId;
    if (uid == null) {
      yield [];
      return;
    }

    final isar = await _courseService.db;
    yield* isar.friends
        .filter()
        .ownerUidEqualTo(uid)
        .watch(fireImmediately: true);
  }

  // 新增好友 (本地)
  Future<String> addFriend(String friendUid, String name) async {
    final uid = currentUserId;
    if (uid == null) return "請先登入";
    if (friendUid == uid) return "不能加自己為好友";

    final isar = await _courseService.db;

    // 檢查是否已經加過
    final existing = await isar.friends
        .filter()
        .ownerUidEqualTo(uid)
        .and()
        .friendUidEqualTo(friendUid)
        .findFirst();

    if (existing != null) {
      return "您已經加過此代碼為好友了";
    }

    final newFriend = Friend()
      ..ownerUid = uid
      ..friendUid = friendUid
      ..name = name;

    try {
      await isar.writeTxn(() async {
        await isar.friends.put(newFriend);
      });
      return "好友已加入！";
    } catch (e) {
      print('加入好友失敗: $e');
      return "發生錯誤，請稍後再試";
    }
  }

  // 刪除好友
  Future<void> removeFriend(int friendId) async {
    final isar = await _courseService.db;
    try {
      await isar.writeTxn(() async {
        await isar.friends.delete(friendId);
      });
    } catch (e) {
      print('移除好友失敗: $e');
    }
  }
}
