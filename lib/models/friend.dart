import 'package:isar/isar.dart';

part 'friend.g.dart';

@collection
class Friend {
  Id id = Isar.autoIncrement; // 本地自增 ID

  @Index(type: IndexType.value)
  late String ownerUid; // 誰加的 (目前登入者的 UID)

  late String friendUid; // 好友的專屬代碼 UID

  late String name; // 使用者自訂的好友暱稱
}
