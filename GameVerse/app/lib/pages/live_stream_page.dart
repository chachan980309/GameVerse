import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/live_stream_service.dart';

class LiveStreamPage extends StatefulWidget {
  const LiveStreamPage({
    super.key,
    required this.streamId,
    required this.roomName,
    required this.title,
    required this.isHost,
  });

  final String streamId;
  final String roomName;
  final String title;
  final bool isHost;

  @override
  State<LiveStreamPage> createState() => _LiveStreamPageState();
}

class _LiveStreamPageState extends State<LiveStreamPage> {
  final LiveStreamService _liveService = LiveStreamService();

  Room? _room;
  bool _connecting = true;
  bool _isLive = true;
  String? _error;
  VideoTrack? _screenTrack;
  Timer? _ticker;

  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  static const _purple = Color(0xff8B4DFF);
  static const _red = Color(0xffD9485F);

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _chatController.dispose();
    _chatScrollController.dispose();
    _disconnect();
    super.dispose();
  }

  Future<void> _connect() async {
    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      if (session == null) throw Exception('Sesión expirada.');

      final stream = await _liveService.getActiveStream(widget.streamId);
      if (stream == null) {
        setState(() {
          _isLive = false;
          _connecting = false;
          _error = 'Este directo ya ha terminado.';
        });
        return;
      }
      final effectiveRoom = (widget.roomName.isNotEmpty)
          ? widget.roomName
          : stream['room_name'].toString();

      final response = await supabase.functions.invoke(
        'livekit-token',
        body: {'room': effectiveRoom, 'roomType': 'live'},
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final token = data['token']?.toString() ?? '';
      final url = data['url']?.toString() ?? '';
      if (token.split('.').length != 3) throw Exception('Token inválido.');

      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(
            encoding: AudioEncoding(maxBitrate: 128000),
          ),
          defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
            params: VideoParametersPresets.screenShareH1080FPS30,
            captureScreenAudio: true,
          ),
          defaultVideoPublishOptions: VideoPublishOptions(
            simulcast: true,
            videoEncoding: VideoEncoding(
              maxBitrate: 6000000,
              maxFramerate: 30,
            ),
            screenShareEncoding: VideoEncoding(
              maxBitrate: 6000000,
              maxFramerate: 30,
            ),
          ),
        ),
      );
      _room = room;

      room.addListener(_onRoomChanged);
      await room.prepareConnection(url, token);
      await room.connect(url, token);
      await room.startAudio();

      if (widget.isHost) {
        await room.localParticipant?.setMicrophoneEnabled(true);
        await room.localParticipant?.setScreenShareEnabled(true);
      }

      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          if (mounted) setState(() {});
        },
      );

      if (mounted) setState(() => _connecting = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = 'No se pudo conectar: $e';
        });
      }
    }
  }

  void _onRoomChanged() {
    if (!mounted) return;
    VideoTrack? found;
    for (final p in (_room?.remoteParticipants.values ?? <RemoteParticipant>[])) {
      final pubs = p.videoTrackPublications;
      for (final pub in List.of(pubs)) {
        final track = pub.track;
        if (track is VideoTrack && !pub.muted) {
          if (pub is RemoteTrackPublication && pub.subscribed) {
            pub.setVideoQuality(VideoQuality.HIGH);
          }
          found = track;
          break;
        }
      }
      if (found != null) break;
    }
    setState(() => _screenTrack = found);
  }

  Future<void> _endStream() async {
    await _liveService.endLiveStream(widget.streamId);
    await _disconnect();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _leaveStream() async {
    await _disconnect();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _disconnect() async {
    _ticker?.cancel();
    _room?.removeListener(_onRoomChanged);
    await _room?.disconnect();
    await _room?.dispose();
    _room = null;
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    _chatController.clear();
    try {
      await _liveService.sendMessage(streamId: widget.streamId, message: text);
    } catch (_) {}
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0A080F),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildBody()),
                  _buildChatPanel(),
                ],
              ),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xff12101E),
        border: Border(bottom: BorderSide(color: Color(0xff38264F))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: widget.isHost ? null : _leaveStream,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isLive ? _red : Colors.grey,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLive)
                  const Icon(Icons.circle, color: Colors.white, size: 8),
                if (_isLive) const SizedBox(width: 5),
                Text(
                  _isLive ? 'EN DIRECTO' : 'FINALIZADO',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.isHost)
            FilledButton.icon(
              onPressed: _endStream,
              style: FilledButton.styleFrom(backgroundColor: _red),
              icon: const Icon(Icons.stop_rounded, size: 18),
              label: const Text('Finalizar'),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_connecting) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _purple),
            SizedBox(height: 16),
            Text('Conectando...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _red, size: 60),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(backgroundColor: _purple),
              child: const Text('Volver'),
            ),
          ],
        ),
      );
    }

    if (widget.isHost) {
      return Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xff08070C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _red.withValues(alpha: 0.6)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.screen_share_rounded, color: _red, size: 80),
            const SizedBox(height: 16),
            const Text(
              'Estás transmitiendo en directo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tus seguidores pueden ver tu pantalla en el feed',
              style: TextStyle(color: Color(0xffA39DAD), fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_screenTrack != null) {
      return Container(
        margin: const EdgeInsets.all(12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _red.withValues(alpha: 0.6)),
        ),
        child: VideoTrackRenderer(_screenTrack!),
      );
    }

    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _red),
          SizedBox(height: 16),
          Text(
            'Esperando la transmisión...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel() {
    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: Color(0xff0F0D19),
        border: Border(left: BorderSide(color: Color(0xff38264F))),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xff38264F))),
            ),
            child: const Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded, color: _purple, size: 18),
                SizedBox(width: 8),
                Text(
                  'Chat en directo',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _liveService.subscribeToMessages(widget.streamId),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Sé el primero en comentar',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                _scrollChatToBottom();
                return ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (_, i) => _buildChatMessage(messages[i]),
                );
              },
            ),
          ),
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildChatMessage(Map<String, dynamic> msg) {
    final username = msg['username']?.toString() ?? 'Usuario';
    final message = msg['message']?.toString() ?? '';
    final avatarUrl = msg['avatar_url']?.toString();
    final isMe = msg['user_id']?.toString() ==
        Supabase.instance.client.auth.currentUser?.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xff38264F),
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? NetworkImage(avatarUrl)
                : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? Text(
                    username[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: TextStyle(
                    color: isMe ? _purple : const Color(0xffC8A0E8),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xff38264F))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLength: 200,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje...',
                hintStyle: const TextStyle(color: Color(0xff777383), fontSize: 13),
                filled: true,
                fillColor: const Color(0xff100D1A),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xff49306B)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xff49306B)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: _purple, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: _purple,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 17),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    if (widget.isHost) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
          color: Color(0xff12101E),
          border: Border(top: BorderSide(color: Color(0xff38264F))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_tethering_rounded, color: _red, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Transmitiendo en directo',
              style: TextStyle(color: Colors.white70),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _endStream,
              style: FilledButton.styleFrom(backgroundColor: _red),
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Finalizar directo'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xff12101E),
        border: Border(top: BorderSide(color: Color(0xff38264F))),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_rounded, color: Colors.white54, size: 18),
          const SizedBox(width: 8),
          const Text('Viendo el directo', style: TextStyle(color: Colors.white70)),
          const Spacer(),
          TextButton.icon(
            onPressed: _leaveStream,
            icon: const Icon(Icons.exit_to_app_rounded, color: Colors.white54),
            label: const Text('Salir', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
