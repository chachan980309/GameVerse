class PostModel {
  final String id;
  final String userId;

  final String content;

  final String? game;
  final String? imageUrl;
  final String? videoUrl;

  final String type;

  final DateTime createdAt;

  // Datos del perfil
  final String username;
  final String avatarUrl;
  final PostModel? sharedPost;

  const PostModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.username,
    required this.avatarUrl,
    this.game,
    this.imageUrl,
    this.videoUrl,
    this.sharedPost,
  });

  factory PostModel.fromMap(Map<String, dynamic> map) {
    final profile = map["profiles"] as Map<String, dynamic>?;
    final shared = map['shared_post'];

    return PostModel(
      id: map["id"],
      userId: map["user_id"],
      content: map["content"] ?? "",

      game: map["game"],
      imageUrl: map["image"],
      videoUrl: map["video"],

      type: map["type"] ?? "text",

      createdAt: DateTime.parse(map["created_at"]),

      username: profile?["username"] ?? "Usuario",
      avatarUrl: profile?["avatar_url"] ?? "",
      sharedPost: shared is Map<String, dynamic>
          ? PostModel.fromMap(shared)
          : null,
    );
  }
}
