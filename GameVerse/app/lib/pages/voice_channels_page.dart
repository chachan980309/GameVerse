import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/profile_controller.dart';
import '../controllers/voice_room_controller.dart';
import '../models/voice_channel.dart';
import '../services/image_picker_service.dart';
import '../services/voice_channel_service.dart';

class VoiceChannelsPage extends StatefulWidget {
  const VoiceChannelsPage({super.key});

  @override
  State<VoiceChannelsPage> createState() => _VoiceChannelsPageState();
}

class _VoiceChannelsPageState extends State<VoiceChannelsPage> {
  static List<VoiceChannel>? _cachedChannels;
  static List<VoiceChannel>? _cachedJoinedChannels;

  String _query = '';
  VoiceChannel? _activeChannel;
  List<VoiceChannel> _channels = const [];
  List<VoiceChannel> _joinedChannels = const [];
  VoiceChannel? _roomChannel;
  final VoiceChannelService _channelService = VoiceChannelService();
  final VoiceRoomController _voiceController = VoiceRoomController();
  final _chatInputController = TextEditingController();
  Timer? _searchDebounce;
  RealtimeChannel? _chatChannel;
  bool _loadingChannels = true;
  bool _joining = false;
  String? _channelsError;
  bool _muted = false;
  bool _deafened = false;
  bool _streaming = false;
  bool _watchingScreenShare = false;
  String? _screenSharerId;
  List<({String type, String user, String text, DateTime time})> _activityLog = [];
  Set<String> _previousParticipantIds = {};
  Set<String> _previousScreenSharers = {};

  Color get _purple => const Color(0xff8B4DFF);

  @override
  void initState() {
    super.initState();
    _voiceController.addListener(_onVoiceChanged);

    if (_cachedChannels != null) _channels = _cachedChannels!;
    if (_cachedJoinedChannels != null) _joinedChannels = _cachedJoinedChannels!;
    _loadingChannels = _channels.isEmpty;

    if (_voiceController.isConnected && _voiceController.connectedChannel != null) {
      _activeChannel = _voiceController.connectedChannel;
      _roomChannel = _voiceController.connectedChannel;
      _enterRoomView(_roomChannel!);
    }
    _loadChannels();
  }

  void _enterRoomView(VoiceChannel channel) {
    _loadChatHistory(channel.id);
    _subscribeToVoiceChat(channel.id);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _voiceController.removeListener(_onVoiceChanged);
    _unsubscribeFromVoiceChat();
    _chatInputController.dispose();
    super.dispose();
  }

  void _onVoiceChanged() {
    if (!mounted) return;

    final currentParticipants = _voiceController.participants;
    final currentIds = currentParticipants.map((p) => p.id).toSet();
    final currentSharers = currentParticipants.where((p) => p.isScreenSharing).map((p) => p.id).toSet();

    // Sincronizar eventos de audio en el canal mediante Supabase de forma compartida
    if (_activeChannel != null) {
      if (_muted != _voiceController.microphoneMuted) {
        _logVoiceEvent(
          channelId: _activeChannel!.id,
          type: 'mic_toggle',
          message: _voiceController.microphoneMuted ? 'silenció su micrófono' : 'activó su micrófono',
        );
      }
      if (_deafened != _voiceController.deafened) {
        _logVoiceEvent(
          channelId: _activeChannel!.id,
          type: 'deafen_toggle',
          message: _voiceController.deafened ? 'silenció el audio del canal' : 'activó el audio del canal',
        );
      }
    }

    setState(() {
      _muted = _voiceController.microphoneMuted;
      _deafened = _voiceController.deafened;
      _streaming = _voiceController.isScreenSharing;
      _screenSharerId = currentParticipants
          .where((p) => p.isScreenSharing)
          .map((p) => p.id)
          .firstOrNull;
      if (_screenSharerId == null) _watchingScreenShare = false;

      _previousParticipantIds = currentIds;
      _previousScreenSharers = currentSharers;
    });

    final error = _voiceController.errorMessage;
    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        _voiceController.clearError();
      });
    }
  }

  Future<void> _loadChannels() async {
    final hasCache = _cachedChannels != null && _cachedJoinedChannels != null;
    if (mounted && !hasCache) setState(() => _loadingChannels = true);
    try {
      final results = await Future.wait([
        _channelService.fetchChannels(query: _query),
        _channelService.fetchJoinedChannels(),
      ]);
      if (!mounted) return;
      setState(() {
        _channels = results[0];
        _joinedChannels = results[1];
        _cachedChannels = results[0];
        _cachedJoinedChannels = results[1];
        _channelsError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _channelsError = 'No se pudieron cargar los canales.');
    } finally {
      if (mounted) setState(() => _loadingChannels = false);
    }
  }

  Future<void> _loadChatHistory(String channelId) async {
    try {
      final rows = await Supabase.instance.client
          .from('voice_channel_messages')
          .select()
          .eq('channel_id', channelId)
          .order('created_at', ascending: true)
          .limit(50);

      if (!mounted) return;
      setState(() {
        _activityLog = rows.map((row) {
          return (
            type: row['message_type']?.toString() ?? 'text',
            user: row['username']?.toString() ?? 'Usuario',
            text: row['message']?.toString() ?? '',
            time: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
          );
        }).toList();
      });
    } catch (e) {
      debugPrint("Error cargando historial de chat: $e");
    }
  }

  Future<void> _logVoiceEvent({
    required String channelId,
    required String type,
    required String message,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      print("No se puede registrar el evento de voz: Usuario no autenticado.");
      return;
    }

    final profile = ProfileController.instance;
    final username = profile.username ?? user.email?.split('@').first ?? 'Usuario';
    final avatarUrl = profile.avatarUrl ?? '';

    try {
      print("Ejecutando insert a Supabase sobre voice_channel_messages...");
      await Supabase.instance.client.from('voice_channel_messages').insert({
        'channel_id': channelId,
        'user_id': user.id,
        'username': username,
        'avatar_url': avatarUrl,
        'message_type': type,
        'message': message,
      });
      print("¡Insert de Supabase completado con éxito!");
    } catch (e, stack) {
      print("ERROR REAL EN INSERT DE SUPABASE: $e");
      print(stack.toString());
    }
  }

  void _subscribeToVoiceChat(String channelId) {
    _unsubscribeFromVoiceChat();

    _chatChannel = Supabase.instance.client
        .channel('voice-channel-chat-$channelId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'voice_channel_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'channel_id',
            value: channelId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            final type = row['message_type']?.toString() ?? 'text';
            final user = row['username']?.toString() ?? 'Usuario';
            final text = row['message']?.toString() ?? '';
            final time = DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now();

            if (mounted) {
              setState(() {
                final isDuplicateText = type == 'text' && user == (ProfileController.instance.username ?? 'Tú') && _activityLog.any((l) => l.type == 'text' && l.text == text && DateTime.now().difference(l.time).inSeconds < 3);
                if (!isDuplicateText) {
                  _activityLog.add((
                    type: type,
                    user: user,
                    text: text,
                    time: time,
                  ));
                }
              });
            }
          },
        )
        .subscribe();
  }

  void _unsubscribeFromVoiceChat() {
    final channel = _chatChannel;
    _chatChannel = null;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
  }

  void _search(String value) {
    _query = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadChannels);
  }

  @override
  Widget build(BuildContext context) {
    if (_roomChannel != null) return _buildChannelRoom(_roomChannel!);

    final featured = _channels.where((channel) => channel.isFeatured).toList();
    final filtered = _channels.where((channel) => !channel.isFeatured).toList();

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 112),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Canales de voz',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _showCreateChannelDialog,
                  style: FilledButton.styleFrom(
                    backgroundColor: _purple,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Crear canal'),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Text(
              'Únete a canales de voz y juega con tu comunidad',
              style: TextStyle(color: Color(0xffA7A3B5), fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              onChanged: _search,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar un canal',
                hintStyle: const TextStyle(color: Color(0xff777383)),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xff8D889A),
                ),
                filled: true,
                fillColor: const Color.fromRGBO(20, 18, 35, 0.92),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_joinedChannels.isNotEmpty) ...[
              _sectionTitle(Icons.bookmark_rounded, 'MIS CANALES'),
              const SizedBox(height: 10),
              ..._joinedChannels.map((channel) => _channelCard(channel)),
              const SizedBox(height: 20),
            ],
            if (featured.isNotEmpty) ...[
              _sectionTitle(Icons.star_rounded, 'CANALES DESTACADOS'),
              const SizedBox(height: 10),
              ...featured.map((channel) => _featuredCard(channel)),
              const SizedBox(height: 20),
            ],
            _sectionTitle(Icons.tag_rounded, 'TODOS LOS CANALES'),
            const SizedBox(height: 10),
            if (_loadingChannels)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_channelsError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    _channelsError!,
                    style: const TextStyle(color: Color(0xffFF809A)),
                  ),
                ),
              )
            else if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No se encontraron canales',
                    style: TextStyle(color: Color(0xff9994A7)),
                  ),
                ),
              )
            else
              ...filtered.map((channel) => _channelCard(channel)),
          ],
        ),
        if (_activeChannel != null) _voiceControls(),
      ],
    );
  }

  Widget _sectionTitle(IconData icon, String title) => Row(
    children: [
      Icon(icon, size: 17, color: const Color(0xffC4BED0)),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          color: Color(0xffC4BED0),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _featuredCard(VoiceChannel channel) {
    final active = _activeChannel == channel;
    final isCurrentlyConnected = _voiceController.isConnected && _voiceController.connectedChannelId == channel.id;
    final highlighted = active || isCurrentlyConnected;

    return _channelContainer(
      active: highlighted,
      child: Row(
        children: [
          _channelIcon(channel),
          const SizedBox(width: 14),
          Expanded(child: _channelInfo(channel)),
          const SizedBox(width: 8),
          _buildMembersIndicator(channel),
          const SizedBox(width: 14),
          Icon(
            highlighted ? Icons.graphic_eq_rounded : Icons.multitrack_audio_rounded,
            color: _purple,
            size: 28,
          ),
        ],
      ),
      onTap: () => _join(channel),
    );
  }

  Widget _channelCard(VoiceChannel channel) {
    final active = _activeChannel == channel;
    final isCurrentlyConnected = _voiceController.isConnected && _voiceController.connectedChannelId == channel.id;
    final highlighted = active || isCurrentlyConnected;

    return _channelContainer(
      active: highlighted,
      child: Row(
        children: [
          _channelIcon(channel),
          const SizedBox(width: 14),
          Expanded(child: _channelInfo(channel)),
          const SizedBox(width: 8),
          _buildMembersIndicator(channel),
          const SizedBox(width: 16),
          OutlinedButton(
            onPressed: _joining ? null : () => _join(channel),
            style: OutlinedButton.styleFrom(
              foregroundColor: highlighted ? Colors.white : const Color(0xffA873FF),
              backgroundColor: highlighted ? _purple : Colors.transparent,
              side: BorderSide(
                color: highlighted ? _purple : const Color(0xff55308B),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(isCurrentlyConnected ? 'Entrar' : 'Unirse'),
          ),
          if (channel.createdBy == Supabase.instance.client.auth.currentUser?.id) ...[
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 21),
              onPressed: () => _deleteChannel(channel),
              tooltip: 'Eliminar canal',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
      onTap: () => _join(channel),
    );
  }

  Widget _buildMembersIndicator(VoiceChannel channel) {
    if (channel.members.isEmpty) {
      return const Text(
        'Vacío',
        style: TextStyle(
          color: Colors.white38,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < math.min(3, channel.members.length); i++)
              Align(
                widthFactor: 0.6,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xff120F22), width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: const Color(0xff5D3487),
                    backgroundImage: channel.members[i].avatarUrl.isNotEmpty
                        ? NetworkImage(channel.members[i].avatarUrl)
                        : null,
                    child: channel.members[i].avatarUrl.isEmpty
                        ? const Icon(Icons.person, size: 10, color: Colors.white)
                        : null,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
        Text(
          '${channel.members.length} conectados',
          style: const TextStyle(
            color: Color(0xffCBC6D3),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _channelContainer({
    required bool active,
    required Widget child,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: active
          ? const Color.fromRGBO(73, 38, 125, 0.75)
          : const Color.fromRGBO(18, 15, 34, 0.88),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: active ? _purple : const Color(0xff332249),
            ),
          ),
          child: child,
        ),
      ),
    ),
  );

  Widget _channelIcon(VoiceChannel channel) {
    if (channel.avatarUrl.isNotEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xff7540BD), width: 1.5),
          image: DecorationImage(
            image: NetworkImage(channel.avatarUrl),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    final icon = _iconFor(channel);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color.fromRGBO(84, 45, 140, 0.35),
        border: Border.all(color: const Color(0xff7540BD)),
      ),
      child: Icon(icon, color: const Color(0xffC799FF), size: 22),
    );
  }

  Widget _channelInfo(VoiceChannel channel) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        channel.name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        channel.description,
        style: const TextStyle(color: Color(0xff9893A4), fontSize: 13),
      ),
    ],
  );

  Widget _memberStack(int members) => Row(
    children: [
      for (var index = 0; index < 3; index++)
        Align(
          widthFactor: 0.75,
          child: CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xff5D3487),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      const SizedBox(width: 5),
      Text(
        '+$members',
        style: const TextStyle(color: Color(0xffA39EAC), fontSize: 12),
      ),
    ],
  );

  Widget _voiceControls() => Positioned(
    left: 28,
    right: 28,
    bottom: 18,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xff171323),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xff59338A)),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 18)],
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xff50E6A5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _activeChannel!.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'Voz conectada',
                  style: TextStyle(color: Color(0xff50E6A5), fontSize: 12),
                ),
              ],
            ),
          ),
          _controlButton(
            icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            active: _muted,
            onTap: _voiceController.toggleMute,
          ),
          const SizedBox(width: 8),
          _controlButton(
            icon: _deafened
                ? Icons.headset_off_rounded
                : Icons.headphones_rounded,
            active: _deafened,
            onTap: _voiceController.toggleDeafen,
          ),
          const SizedBox(width: 8),
          _controlButton(
            icon: Icons.settings_rounded,
            active: false,
            onTap: _showAudioDevices,
            tooltip: 'Configurar micrófono y audífonos',
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _leaveVoiceRoom,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffD64A68),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            icon: const Icon(Icons.call_end_rounded, size: 19),
            label: const Text('Salir'),
          ),
        ],
      ),
    ),
  );

  Widget _controlButton({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    String? tooltip,
  }) => IconButton(
    onPressed: onTap,
    tooltip: tooltip,
    style: IconButton.styleFrom(
      backgroundColor: active
          ? const Color(0xff6A3450)
          : const Color(0xff29233A),
      foregroundColor: active ? const Color(0xffFF809A) : Colors.white,
      padding: const EdgeInsets.all(13),
    ),
    icon: Icon(icon),
  );

  IconData _iconFor(VoiceChannel channel) {
    final name = channel.name.toLowerCase();
    if (name.contains('música') || name.contains('music')) {
      return Icons.music_note_rounded;
    }
    if (name.contains('torneo')) return Icons.emoji_events_rounded;
    if (name.contains('minecraft')) return Icons.catching_pokemon_rounded;
    if (name.contains('league') ||
        name.contains('valorant') ||
        name.contains('fortnite')) {
      return Icons.sports_esports_rounded;
    }
    return Icons.graphic_eq_rounded;
  }

  Future<void> _join(VoiceChannel channel) async {
    if (_joining) return;

    // Si ya estamos conectados a este canal, simplemente entramos a la sala visualmente
    if (_voiceController.isConnected && _voiceController.connectedChannelId == channel.id) {
      setState(() {
        _activeChannel = channel;
        _roomChannel = channel;
        _muted = _voiceController.microphoneMuted;
        _deafened = _voiceController.deafened;
        _streaming = _voiceController.isScreenSharing;
      });
      _enterRoomView(channel);
      return;
    }

    setState(() => _joining = true);
    try {
      await _channelService.joinChannel(channel.id);
      final connected = await _voiceController.connect(channel.roomName, channel: channel);
      if (!mounted) return;
      if (!connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _voiceController.errorMessage ??
                  'No se pudo conectar con el canal de voz.',
            ),
          ),
        );
        return;
      }
      setState(() {
        if (!_joinedChannels.any((item) => item.id == channel.id)) {
          _joinedChannels = [channel, ..._joinedChannels];
          _cachedJoinedChannels = _joinedChannels;
        }
        _activeChannel = channel;
        _roomChannel = channel;
        _muted = _voiceController.microphoneMuted;
        _deafened = _voiceController.deafened;
        _streaming = false;
      });
      _enterRoomView(channel);
      _logVoiceEvent(channelId: channel.id, type: 'join', message: 'entró al canal');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo entrar al canal: $error')),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _showCreateChannelDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    Uint8List? selectedImageBytes;

    final channelData = await showDialog<({String name, String description, Uint8List? avatarBytes})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: const Color(0xff191525),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text(
              'Crear canal de voz',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar de Canal
                  GestureDetector(
                    onTap: () async {
                      final bytes = await ImagePickerService.pickImage();
                      if (bytes != null) {
                        setStateDialog(() {
                          selectedImageBytes = bytes;
                        });
                      }
                    },
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xff29233A),
                        shape: BoxShape.circle,
                        border: Border.all(color: _purple, width: 2),
                        image: selectedImageBytes != null
                            ? DecorationImage(
                                image: MemoryImage(selectedImageBytes!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: selectedImageBytes == null
                          ? const Icon(Icons.add_a_photo_rounded, color: Colors.white70, size: 24)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Avatar del canal (opcional)',
                    style: TextStyle(color: Color(0xff9893A4), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  _dialogField(
                    controller: nameController,
                    label: 'Nombre del canal',
                    hint: 'Ej. Squad competitivo',
                  ),
                  const SizedBox(height: 14),
                  _dialogField(
                    controller: descriptionController,
                    label: 'Descripción',
                    hint: '¿De qué se hablará en este canal?',
                    maxLength: 90,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(dialogContext, (
                    name: name,
                    description: descriptionController.text.trim().isEmpty
                        ? 'Canal creado por ti'
                        : descriptionController.text.trim(),
                    avatarBytes: selectedImageBytes,
                  ));
                },
                style: FilledButton.styleFrom(backgroundColor: _purple),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crear y unirme'),
              ),
            ],
          );
        },
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
    if (channelData == null || !mounted) return;
    try {
      String? avatarUrl;
      if (channelData.avatarBytes != null) {
        // Subir imagen de canal bajo la carpeta del ID de usuario para cumplir con las políticas RLS del bucket avatars
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          final uniqueId = DateTime.now().millisecondsSinceEpoch;
          final path = '$userId/channel_$uniqueId.png';
          await Supabase.instance.client.storage
              .from('avatars')
              .uploadBinary(
                path,
                channelData.avatarBytes!,
                fileOptions: const FileOptions(contentType: 'image/png'),
              );
          avatarUrl = path; // Almacenamos la ruta corta relativa
        }
      }

      final channel = await _channelService.createChannel(
        name: channelData.name,
        description: channelData.description,
        avatarUrl: avatarUrl,
      );
      if (!mounted) return;
      setState(() {
        _channels = [channel, ..._channels];
        _cachedChannels = _channels;
      });
      await _join(channel);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo crear el canal.')),
      );
    }
  }

  Future<void> _deleteChannel(VoiceChannel channel) async {
    bool hasConnectedUsers = false;

    // Comprobar únicamente los usuarios realmente conectados mediante el estado real de la sesión WebRTC/presence
    if (_voiceController.isConnected && _voiceController.connectedChannelId == channel.id) {
      // Excluir al usuario local. Si hay más participantes en la llamada de WebRTC, impedir eliminar.
      hasConnectedUsers = _voiceController.participants.where((p) => !p.isLocal).isNotEmpty;
    }

    if (hasConnectedUsers) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se puede eliminar el canal porque hay usuarios conectados.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    // 2. Pedir confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xff191525),
        title: const Text('¿Eliminar canal?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('¿Estás seguro de que deseas eliminar "${channel.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 3. Eliminar de Supabase (físicamente mediante DELETE)
    try {
      await Supabase.instance.client
          .from('voice_channels')
          .delete()
          .eq('id', channel.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Canal eliminado correctamente.')),
        );
        setState(() {
          _channels.removeWhere((item) => item.id == channel.id);
          _joinedChannels.removeWhere((item) => item.id == channel.id);
          _cachedChannels = _channels;
          _cachedJoinedChannels = _joinedChannels;
          if (_activeChannel?.id == channel.id) {
            _activeChannel = null;
            _roomChannel = null;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar el canal.')),
        );
      }
    }
  }

  Widget _buildChannelRoom(VoiceChannel channel) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
          decoration: const BoxDecoration(
            color: Color.fromRGBO(12, 10, 22, 0.94),
            border: Border(bottom: BorderSide(color: Color(0xff38264F))),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Volver a canales',
                onPressed: () {
                  _unsubscribeFromVoiceChat();
                  setState(() => _roomChannel = null);
                },
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              const SizedBox(width: 8),
              _channelIcon(channel),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${_voiceController.participants.length} conectados · Canal de voz',
                      style: const TextStyle(
                        color: Color(0xffA39DAD),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (_streaming || _screenSharerId != null)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xffD9485F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'EN DIRECTO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (_streaming)
                OutlinedButton.icon(
                  onPressed: _toggleScreenShare,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xffD9485F)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  icon: const Icon(Icons.stop_screen_share_rounded),
                  label: const Text('Detener directo'),
                )
              else if (_screenSharerId != null)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _watchingScreenShare = !_watchingScreenShare),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: _watchingScreenShare ? const Color(0xffD9485F) : _purple,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  icon: Icon(_watchingScreenShare
                      ? Icons.stop_screen_share_rounded
                      : Icons.screen_share_rounded),
                  label: Text(_watchingScreenShare ? 'Dejar de ver' : 'Ver transmisión'),
                )
              else
                OutlinedButton.icon(
                  onPressed: _toggleScreenShare,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: _purple),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  icon: const Icon(Icons.screen_share_rounded),
                  label: const Text('Transmitir'),
                ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 96), // Margen inferior aumentado para dar espacio al panel flotante
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'EN EL CANAL DE VOZ',
                            style: TextStyle(
                              color: Color(0xffB9B3C3),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_voiceController.participants.length} miembros',
                            style: const TextStyle(
                              color: Color(0xff8D8797),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: (_streaming || _watchingScreenShare)
                            ? _liveStage(isOwner: _streaming)
                            : Column(
                                children: [
                                  Expanded(child: _liveStage(isOwner: false, hasStream: false)),
                                  const SizedBox(height: 14),
                                  SizedBox(height: 140, child: _participantsGrid()),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(width: 1, color: const Color(0xff38264F)),
              SizedBox(width: 280, child: _channelChat(channel)),
            ],
          ),
        ),
        _roomControls(channel),
      ],
    );
  }

  Widget _participantsGrid() {
    final users = _voiceController.participants;
    if (users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 130, // Reducida para que se adapte perfectamente al pie de pantalla sin robar espacio
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Container(
          decoration: BoxDecoration(
            color: const Color.fromRGBO(22, 18, 35, 0.94),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: user.isSpeaking
                  ? const Color(0xff50E6A5)
                  : const Color(0xff3C2A50),
              width: user.isSpeaking ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xff5D3487),
                    backgroundImage: user.avatarUrl.isNotEmpty
                        ? NetworkImage(user.avatarUrl)
                        : null,
                    child: user.avatarUrl.isEmpty
                        ? Text(
                            user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  if (user.isScreenSharing)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _purple,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xff16121F),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.screen_share_rounded,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                user.isLocal ? '${user.name} (Tú)' : user.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                user.isSpeaking
                    ? 'Hablando · ${_connectedTime(user.connectedFor)}'
                    : user.isMuted
                    ? 'Silenciado · ${_connectedTime(user.connectedFor)}'
                    : 'En el canal · ${_connectedTime(user.connectedFor)}',
                style: TextStyle(
                  color: user.isSpeaking
                      ? const Color(0xff50E6A5)
                      : const Color(0xff918B9B),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _liveStage({required bool isOwner, bool hasStream = true}) {
    if (!hasStream) {
      // ESTADO VACÍO ATRACTIVO (CAMBIO 6)
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xff120F1F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xff33264F)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.screen_share_rounded, color: _purple.withOpacity(0.35), size: 76),
            const SizedBox(height: 16),
            const Text(
              'Nadie está compartiendo pantalla',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _toggleScreenShare,
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.screen_share_rounded, size: 18),
              label: const Text('Compartir pantalla', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    final remoteTrack = isOwner ? null : _voiceController.remoteScreenShareTrack;
    final sharerName = _voiceController.participants
        .where((p) => p.id == _screenSharerId)
        .map((p) => p.name)
        .firstOrNull ?? "Alguien";

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xff08070C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff68419B)),
      ),
      child: Stack(
        children: [
          // 1. TRANSMISIÓN DE VIDEO O HOST ANNOUNCEMENT (CAMBIO 1)
          isOwner
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.screen_share_rounded, color: _purple, size: 70),
                      const SizedBox(height: 15),
                      const Text(
                        'Estás transmitiendo tu pantalla',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Los miembros del canal pueden ver tu directo',
                        style: TextStyle(color: Color(0xff96909F)),
                      ),
                    ],
                  ),
                )
              : remoteTrack != null
                  ? Center(child: VideoTrackRenderer(remoteTrack))
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.screen_share_rounded, color: _purple, size: 60),
                          const SizedBox(height: 14),
                          Text(
                            '$sharerName está transmitiendo',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

          // 2. HEADER DE CONTROL / QUIEN TRANSMITE (CAMBIO 5 y CAMBIO 7)
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xffD9485F),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOwner
                        ? 'Estás transmitiendo tu pantalla'
                        : 'Pantalla compartida por $sharerName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. MINI AVATARES DE PARTICIPANTES EN LA ESQUINA (CAMBIO 2)
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var p in _voiceController.participants)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Tooltip(
                        message: p.name,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: const Color(0xff5D3487),
                          backgroundImage: p.avatarUrl.isNotEmpty ? NetworkImage(p.avatarUrl) : null,
                          child: p.avatarUrl.isEmpty
                              ? Text(
                                  p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 4. BOTONES EN PANTALLA SOBRE EL VIDEO (CAMBIO 3: PANTALLA COMPLETA)
          if (!isOwner && remoteTrack != null)
            Positioned(
              bottom: 14,
              right: 14,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
                      tooltip: 'Pantalla completa',
                      onPressed: () => _openFullScreen(remoteTrack),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openFullScreen(VideoTrack track) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: VideoTrackRenderer(track),
            ),
            Positioned(
              top: 24,
              right: 24,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _connectedTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _submitChatMessage(String value, VoiceChannel channel) {
    final cleanValue = value.trim();
    if (cleanValue.isEmpty) return;

    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    print("Botón pulsado");
    print("Mensaje: $cleanValue");
    print("Channel: ${channel.id}");
    print("User: $userId");

    _chatInputController.clear(); // Limpiar el input inmediatamente

    _logVoiceEvent(
      channelId: channel.id,
      type: 'text',
      message: ': $cleanValue',
    );
  }

  Widget _channelChat(VoiceChannel channel) {
    final scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });

    return Container(
      color: const Color.fromRGBO(15, 12, 25, 0.94),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACTIVIDAD DEL CANAL',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          Text(
            '#${channel.name}',
            style: const TextStyle(color: Color(0xff918B9B), fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const Divider(height: 25, color: Color(0xff38264F)),
          Expanded(
            child: _activityLog.isEmpty
                ? const Center(
                    child: Text(
                      'No hay actividades aún.',
                      style: TextStyle(color: Color(0xff777383), fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    itemCount: _activityLog.length,
                    itemBuilder: (context, index) {
                      final log = _activityLog[index];
                      IconData? icon;
                      Color color = Colors.white70;
                      TextStyle style = const TextStyle(fontSize: 12, color: Colors.white70);

                      if (log.type == 'join') {
                        icon = Icons.login_rounded;
                        color = const Color(0xff50E6A5);
                      } else if (log.type == 'leave') {
                        icon = Icons.logout_rounded;
                        color = const Color(0xffFF809A);
                      } else if (log.type == 'stream_start') {
                        icon = Icons.wifi_tethering_rounded;
                        color = const Color(0xffD9485F);
                      } else if (log.type == 'stream_end') {
                        icon = Icons.wifi_tethering_off_rounded;
                        color = Colors.white38;
                      } else if (log.type == 'system') {
                        color = const Color(0xffB986FF);
                        style = const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xffC5B4FF));
                      } else if (log.type == 'text') {
                        color = Colors.white;
                        style = const TextStyle(fontSize: 13, color: Colors.white);
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (icon != null) ...[
                              Icon(icon, size: 14, color: color),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    if (log.user.isNotEmpty)
                                      TextSpan(
                                        text: '${log.user} ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                          fontSize: 12,
                                        ),
                                      ),
                                    TextSpan(
                                      text: log.text,
                                      style: style,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _chatInputController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            onSubmitted: (value) => _submitChatMessage(value, channel),
            decoration: InputDecoration(
              hintText: 'Escribe un mensaje...',
              hintStyle: const TextStyle(color: Color(0xff777383), fontSize: 12),
              suffixIcon: IconButton(
                icon: Icon(Icons.send_rounded, color: _purple, size: 18),
                onPressed: () => _submitChatMessage(_chatInputController.text, channel),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              filled: true,
              fillColor: const Color(0xff211B30),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roomControls(VoiceChannel channel) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16), // Muro flotante tipo cápsula Discord
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xff161325).withOpacity(0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xff55338B), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Ajustado ceñidamente alrededor de los botones
          children: [
            const Icon(Icons.wifi_tethering_rounded, color: Color(0xff50E6A5), size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _connectionLabel,
                  style: TextStyle(
                    color: _voiceController.status == VoiceConnectionStatus.reconnecting
                        ? const Color(0xffF6C65B)
                        : const Color(0xff50E6A5),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  channel.name,
                  style: const TextStyle(color: Color(0xffA39DAD), fontSize: 11),
                ),
              ],
            ),
            const SizedBox(width: 24),
            _controlButton(
              icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
              active: _muted,
              onTap: _voiceController.toggleMute,
            ),
            const SizedBox(width: 8),
            _controlButton(
              icon: _deafened ? Icons.headset_off_rounded : Icons.headphones_rounded,
              active: _deafened,
              onTap: _voiceController.toggleDeafen,
              tooltip: 'Activar o silenciar el audio',
            ),
            const SizedBox(width: 8),
            _controlButton(
              icon: Icons.settings_rounded,
              active: false,
              onTap: _showAudioDevices,
              tooltip: 'Configurar micrófono y audífonos',
            ),
            const SizedBox(width: 8),
            _controlButton(
              icon: Icons.screen_share_rounded,
              active: _streaming,
              onTap: _toggleScreenShare,
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: _leaveVoiceRoom,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xffD64A68),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              icon: const Icon(Icons.call_end_rounded, size: 16),
              label: const Text('Salir', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  String get _connectionLabel => switch (_voiceController.status) {
    VoiceConnectionStatus.connecting => 'Conectando…',
    VoiceConnectionStatus.reconnecting => 'Reconectando…',
    VoiceConnectionStatus.connected => 'Voz conectada',
    VoiceConnectionStatus.error => 'Error de conexión',
    VoiceConnectionStatus.disconnected => 'Desconectado',
  };

  Future<void> _leaveVoiceRoom() async {
    if (_activeChannel != null) {
      try {
        await _logVoiceEvent(channelId: _activeChannel!.id, type: 'leave', message: 'salió del canal');
        await _channelService.leaveChannel(_activeChannel!.id);
      } catch (_) {}
    }
    _unsubscribeFromVoiceChat();
    await _voiceController.leaveRoom();
    if (!mounted) return;
    setState(() {
      _activeChannel = null;
      _roomChannel = null;
      _streaming = false;
      _watchingScreenShare = false;
      _screenSharerId = null;
    });
  }

  Future<void> _showAudioDevices() async {
    try {
      final inputs = await _voiceController.audioInputs();
      final outputs = await _voiceController.audioOutputs();
      if (!mounted) return;
      final selected = await showDialog<({String id, bool input})>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xff191525),
          title: const Text(
            'Dispositivos de audio',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text(
                  'MICRÓFONO',
                  style: TextStyle(color: Color(0xffA39DAD), fontSize: 11),
                ),
                ...inputs.map(
                  (device) => ListTile(
                    leading: const Icon(
                      Icons.mic_rounded,
                      color: Color(0xffB986FF),
                    ),
                    title: Text(
                      device.label.isEmpty
                          ? 'Micrófono del sistema'
                          : device.label,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () => Navigator.pop(dialogContext, (
                      id: device.deviceId,
                      input: true,
                    )),
                  ),
                ),
                const Divider(color: Color(0xff38264F)),
                const Text(
                  'SALIDA',
                  style: TextStyle(color: Color(0xffA39DAD), fontSize: 11),
                ),
                ...outputs.map(
                  (device) => ListTile(
                    leading: const Icon(
                      Icons.headphones_rounded,
                      color: Color(0xffB986FF),
                    ),
                    title: Text(
                      device.label.isEmpty
                          ? 'Salida del sistema'
                          : device.label,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () => Navigator.pop(dialogContext, (
                      id: device.deviceId,
                      input: false,
                    )),
                  ),
                ),
                SwitchListTile(
                  value: _voiceController.speakerEnabled,
                  activeThumbColor: _purple,
                  title: const Text(
                    'Preferir altavoz',
                    style: TextStyle(color: Colors.white),
                  ),
                  onChanged: (_) async {
                    await _voiceController.toggleSpeaker();
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                ),
              ],
            ),
          ),
        ),
      );
      if (selected == null) return;
      if (selected.input) {
        final device = inputs.firstWhere(
          (item) => item.deviceId == selected.id,
        );
        await _voiceController.selectAudioInput(device);
      } else {
        final device = outputs.firstWhere(
          (item) => item.deviceId == selected.id,
        );
        await _voiceController.selectAudioOutput(device);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cambiar el dispositivo de audio.'),
        ),
      );
    }
  }

  Future<void> _toggleScreenShare() async {
    if (!_voiceController.isConnected || _activeChannel == null) return;
    final startingStream = !_streaming;
    await _voiceController.toggleScreenShare();
    if (_voiceController.isScreenSharing == startingStream) {
      _logVoiceEvent(
        channelId: _activeChannel!.id,
        type: startingStream ? 'stream_start' : 'stream_end',
        message: startingStream ? 'comenzó a compartir pantalla' : 'detuvo su transmisión',
      );
    }
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int? maxLength,
  }) => TextField(
    controller: controller,
    maxLength: maxLength,
    autofocus: label == 'Nombre del canal',
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Color(0xffBFA8E8)),
      hintStyle: const TextStyle(color: Color(0xff777383)),
      counterStyle: const TextStyle(color: Color(0xff777383)),
      filled: true,
      fillColor: const Color(0xff100D1A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xff49306B)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xff49306B)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: _purple, width: 1.5),
      ),
    ),
  );
}