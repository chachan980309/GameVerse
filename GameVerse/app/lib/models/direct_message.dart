class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
    this.sharedPostId,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime createdAt;
  final String? sharedPostId;

  factory DirectMessage.fromMap(Map<String, dynamic> map) => DirectMessage(
    id: map['id'].toString(),
    senderId: map['sender_id'].toString(),
    receiverId: map['receiver_id'].toString(),
    content: map['content']?.toString() ?? '',
    createdAt: DateTime.parse(map['created_at'].toString()),
    sharedPostId: map['shared_post_id']?.toString(),
  );
}
