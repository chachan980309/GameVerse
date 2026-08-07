class ClanEventModel {
  final String id;
  final String clanId;
  final String name;
  final String description;
  final DateTime eventDate;
  final String type; // Torneo, Entrenamiento, Reunión, Evento, Stream
  final String creatorId;
  final String creatorUsername;
  final DateTime createdAt;

  const ClanEventModel({
    required this.id,
    required this.clanId,
    required this.name,
    required this.description,
    required this.eventDate,
    required this.type,
    required this.creatorId,
    required this.creatorUsername,
    required this.createdAt,
  });

  factory ClanEventModel.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>? ?? {};

    return ClanEventModel(
      id: map['id'].toString(),
      clanId: map['clan_id'].toString(),
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      eventDate: DateTime.tryParse(map['event_date']?.toString() ?? '') ?? DateTime.now(),
      type: map['type']?.toString() ?? 'Evento',
      creatorId: map['creator_id'].toString(),
      creatorUsername: profile['username']?.toString() ?? 'Creador',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
