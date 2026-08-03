import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../controllers/voice_room_controller.dart';
import '../models/voice_channel.dart';
import '../services/voice_channel_service.dart';

class VoiceChannelsPage extends StatefulWidget {
  const VoiceChannelsPage({super.key});

  @override
  State<VoiceChannelsPage> createState() => _VoiceChannelsPageState();
}

class _VoiceChannelsPageState extends State<VoiceChannelsPage> {
  String _query = '';
  VoiceChannel? _activeChannel;
  List<VoiceChannel> _channels = const [];
  List<VoiceChannel> _joinedChannels = const [];
  VoiceChannel? _roomChannel;
  final VoiceChannelService _channelService = VoiceChannelService();
  final VoiceRoomController _voiceController = VoiceRoomController();
  Timer? _searchDebounce;
  bool _loadingChannels = true;
  bool _joining = false;
  String? _channelsError;
  bool _muted = false;
  bool _deafened = false;
  bool _streaming = false;
  bool _watchingScreenShare = false;
  String? _screenSharerId;

  Color get _purple => const Color(0xff8B4DFF);

  @override
  void initState() {
    super.initState();
    _voiceController.addListener(_onVoiceChanged);
    _loadChannels();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _voiceController.removeListener(_onVoiceChanged);
    _voiceController.dispose();
    super.dispose();
  }

  void _onVoiceChanged() {
    if (!mounted) return;
    setState(() {
      _muted = _voiceController.microphoneMuted;
      _deafened = _voiceController.deafened;
      _streaming = _voiceController.isScreenSharing;
      _screenSharerId = _voiceController.participants
          .where((p) => p.isScreenSharing)
          .map((p) => p.id)
          .firstOrNull;
      if (_screenSharerId == null) _watchingScreenShare = false;
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
    if (mounted) setState(() => _loadingChannels = true);
    try {
      final results = await Future.wait([
        _channelService.fetchChannels(query: _query),
        _channelService.fetchJoinedChannels(),
      ]);
      if (!mounted) return;
      setState(() {
        _channels = results[0];
        _joinedChannels = results[1];
        _channelsError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _channelsError = 'No se pudieron cargar los canales.');
    } finally {
      if (mounted) setState(() => _loadingChannels = false);
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
    return _channelContainer(
      active: active,
      child: Row(
        children: [
          _channelIcon(_iconFor(channel)),
          const SizedBox(width: 14),
          Expanded(child: _channelInfo(channel)),
          _memberStack(channel.memberCount),
          const SizedBox(width: 14),
          Icon(
            active ? Icons.graphic_eq_rounded : Icons.multitrack_audio_rounded,
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
    return _channelContainer(
      active: active,
      child: Row(
        children: [
          _channelIcon(_iconFor(channel)),
          const SizedBox(width: 14),
          Expanded(child: _channelInfo(channel)),
          const Icon(
            Icons.people_alt_outlined,
            color: Color(0xffA9A4B4),
            size: 17,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 28,
            child: Text(
              '${channel.memberCount}',
              style: const TextStyle(color: Color(0xffCBC6D3)),
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton(
            onPressed: _joining ? null : () => _join(channel),
            style: OutlinedButton.styleFrom(
              foregroundColor: active ? Colors.white : const Color(0xffA873FF),
              backgroundColor: active ? _purple : Colors.transparent,
              side: BorderSide(
                color: active ? _purple : const Color(0xff55308B),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            ),
            child: Text(active ? 'Conectado' : 'Unirse'),
          ),
        ],
      ),
      onTap: () => _join(channel),
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

  Widget _channelIcon(IconData icon) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color.fromRGBO(84, 45, 140, 0.35),
      border: Border.all(color: const Color(0xff7540BD)),
    ),
    child: Icon(icon, color: const Color(0xffC799FF), size: 22),
  );

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
    setState(() => _joining = true);
    try {
      await _channelService.joinChannel(channel.id);
      final connected = await _voiceController.connect(channel.roomName);
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
        }
        _activeChannel = channel;
        _roomChannel = channel;
        _muted = _voiceController.microphoneMuted;
        _deafened = _voiceController.deafened;
        _streaming = false;
      });
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
    final channelData = await showDialog<({String name, String description})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
              ));
            },
            style: FilledButton.styleFrom(backgroundColor: _purple),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear y unirme'),
          ),
        ],
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
    if (channelData == null || !mounted) return;
    try {
      final channel = await _channelService.createChannel(
        name: channelData.name,
        description: channelData.description,
      );
      if (!mounted) return;
      setState(() => _channels = [channel, ..._channels]);
      await _join(channel);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo crear el canal.')),
      );
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
                onPressed: () => setState(() => _roomChannel = null),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              const SizedBox(width: 8),
              _channelIcon(_iconFor(channel)),
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
                  padding: const EdgeInsets.all(20),
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
                        child: _streaming
                            ? _liveStage(isOwner: true)
                            : _watchingScreenShare
                                ? _liveStage(isOwner: false)
                                : _participantsGrid(),
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
        mainAxisExtent: 170,
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
                    radius: 38,
                    backgroundColor: const Color(0xff5D3487),
                    backgroundImage: user.avatarUrl.isNotEmpty
                        ? NetworkImage(user.avatarUrl)
                        : null,
                    child: user.avatarUrl.isEmpty
                        ? Text(
                            user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 27,
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
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                user.isLocal ? '${user.name} (Tú)' : user.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                user.isSpeaking
                    ? 'Hablando · ${_connectedTime(user.connectedFor)}'
                    : user.isMuted
                    ? 'Micrófono silenciado · ${_connectedTime(user.connectedFor)}'
                    : 'En el canal · ${_connectedTime(user.connectedFor)}',
                style: TextStyle(
                  color: user.isSpeaking
                      ? const Color(0xff50E6A5)
                      : const Color(0xff918B9B),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _liveStage({required bool isOwner}) {
    final remoteTrack = isOwner ? null : _voiceController.remoteScreenShareTrack;
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xff08070C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xff68419B)),
            ),
            child: isOwner
                ? Column(
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
                  )
                : remoteTrack != null
                    ? VideoTrackRenderer(remoteTrack)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.screen_share_rounded, color: _purple, size: 60),
                          const SizedBox(height: 14),
                          Text(
                            '${_voiceController.participants.where((p) => p.id == _screenSharerId).map((p) => p.name).firstOrNull ?? "Alguien"} está transmitiendo',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(height: 105, child: _participantsGrid()),
      ],
    );
  }

  String _connectedTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _channelChat(VoiceChannel channel) => Container(
    color: const Color.fromRGBO(15, 12, 25, 0.94),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CHAT DEL CANAL',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          channel.name,
          style: const TextStyle(color: Color(0xff918B9B), fontSize: 12),
        ),
        const Divider(height: 25, color: Color(0xff38264F)),
        const Expanded(
          child: Center(
            child: Text(
              'El chat del canal aparecerá aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xff777383), fontSize: 12),
            ),
          ),
        ),
        TextField(
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Mensaje en #${channel.name}',
            hintStyle: const TextStyle(color: Color(0xff777383), fontSize: 12),
            suffixIcon: Icon(Icons.send_rounded, color: _purple, size: 20),
            filled: true,
            fillColor: const Color(0xff211B30),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _roomControls(VoiceChannel channel) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
    decoration: const BoxDecoration(
      color: Color(0xff171323),
      border: Border(top: BorderSide(color: Color(0xff49306B))),
    ),
    child: Row(
      children: [
        const Icon(Icons.wifi_tethering_rounded, color: Color(0xff50E6A5)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _connectionLabel,
                style: TextStyle(
                  color:
                      _voiceController.status ==
                          VoiceConnectionStatus.reconnecting
                      ? const Color(0xffF6C65B)
                      : const Color(0xff50E6A5),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                channel.name,
                style: const TextStyle(color: Color(0xffA39DAD), fontSize: 12),
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
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _leaveVoiceRoom,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xffD64A68),
          ),
          icon: const Icon(Icons.call_end_rounded),
          label: const Text('Salir'),
        ),
      ],
    ),
  );

  String get _connectionLabel => switch (_voiceController.status) {
    VoiceConnectionStatus.connecting => 'Conectando…',
    VoiceConnectionStatus.reconnecting => 'Reconectando…',
    VoiceConnectionStatus.connected => 'Voz conectada',
    VoiceConnectionStatus.error => 'Error de conexión',
    VoiceConnectionStatus.disconnected => 'Desconectado',
  };

  Future<void> _leaveVoiceRoom() async {
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
    if (!_voiceController.isConnected) return;
    await _voiceController.toggleScreenShare();
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