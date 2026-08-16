class PostModel {
  final String id;
  final String userId;

  final String content;

  final String? game;
  final String? imageUrl;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? duration;
  final int? width;
  final int? height;
  final double? aspectRatio;

  final String type;

  final DateTime createdAt;

  // Datos del perfil
  final String username;
  final String avatarUrl;
  final String? sharedPostId;
  final PostModel? sharedPost;
  final String? streamId;
  final String? clanId;
  final String? clanName;
  final String? pollQuestion;
  final List<String> pollOptions;

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
    this.thumbnailUrl,
    this.duration,
    this.width,
    this.height,
    this.aspectRatio,
    this.sharedPostId,
    this.sharedPost,
    this.streamId,
    this.clanId,
    this.clanName,
    this.pollQuestion,
    this.pollOptions = const [],
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
      thumbnailUrl: map["thumbnail_url"],
      duration: map["duration"],
      width: map["width"] != null
          ? int.tryParse(map["width"].toString())
          : null,
      height: map["height"] != null
          ? int.tryParse(map["height"].toString())
          : null,
      aspectRatio: map["aspect_ratio"] != null
          ? double.tryParse(map["aspect_ratio"].toString())
          : null,

      type: map["type"] ?? "text",
      createdAt:
          DateTime.tryParse(map["created_at"]?.toString() ?? "") ??
          DateTime.now(),
      username: profile?["username"]?.toString() ?? "Usuario",
      avatarUrl: profile?["avatar_url"]?.toString() ?? "",
      sharedPostId: map['shared_post_id']?.toString(),
      sharedPost: shared != null && shared is Map<String, dynamic>
          ? PostModel.fromMap(shared)
          : null,
      streamId: map['stream_id']?.toString(),
      clanId: map['clan_id']?.toString(),
      clanName: map['clans'] != null && map['clans'] is Map<String, dynamic>
          ? (map['clans'] as Map<String, dynamic>)['name']?.toString()
          : null,
      pollQuestion: map['poll_question']?.toString(),
      pollOptions: (map['poll_options'] as List<dynamic>? ?? const [])
          .map((option) => option.toString())
          .where((option) => option.isNotEmpty)
          .toList(),
    );
  }

  bool get isSharedPost =>
      sharedPost != null ||
      sharedPostId != null ||
      type == 'share' ||
      content.toLowerCase().startsWith('comparti');
}
