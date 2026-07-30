class PostModel {

  final String id;
  final String username;
  final String avatar;
  final String content;
  final String? image;
  final int likes;
  final int comments;
  final DateTime createdAt;


  PostModel({

    required this.id,
    required this.username,
    required this.avatar,
    required this.content,
    this.image,
    required this.likes,
    required this.comments,
    required this.createdAt,

  });



  factory PostModel.fromMap(Map<String, dynamic> map) {

    return PostModel(

      id: map['id'],

      username: map['username'],

      avatar: map['avatar'] ?? '',

      content: map['content'],

      image: map['image'],

      likes: map['likes'] ?? 0,

      comments: map['comments'] ?? 0,

      createdAt: DateTime.parse(
        map['created_at'],
      ),

    );

  }

}