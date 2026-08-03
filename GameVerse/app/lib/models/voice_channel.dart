class VoiceChannel {
  const VoiceChannel({
    required this.id,
    required this.name,
    required this.roomName,
    required this.description,
    required this.createdBy,
    required this.isFeatured,
    this.memberCount = 0,
  });

  factory VoiceChannel.fromMap(Map<String, dynamic> map) => VoiceChannel(
    id: map['id'].toString(),
    name: map['name']?.toString() ?? 'Canal de voz',
    roomName: map['room_name']?.toString() ?? '',
    description: map['description']?.toString() ?? '',
    createdBy: map['created_by']?.toString() ?? '',
    isFeatured: map['is_featured'] == true,
  );

  final String id;
  final String name;
  final String roomName;
  final String description;
  final String createdBy;
  final bool isFeatured;
  final int memberCount;
}
