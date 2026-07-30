class FriendModel {
  final String id;
  final String username;
  final bool online;
  final String game;
  final String? avatar;

  const FriendModel({
    required this.id,
    required this.username,
    required this.online,
    required this.game,
    this.avatar,
  });
}