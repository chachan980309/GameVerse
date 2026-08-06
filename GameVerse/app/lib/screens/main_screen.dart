import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/presence_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/voice_room_controller.dart';
import '../pages/feed_page.dart';
import '../pages/profile_page.dart';
import '../pages/friends_page.dart';
import '../pages/voice_channels_page.dart';
import '../pages/tournaments_page.dart';
import '../services/profile_navigation_service.dart';
import '../services/post_navigation_service.dart';
import '../services/spotify_service.dart';

import '../widgets/layout/sidebar.dart';
import '../widgets/layout/right_panel.dart';
import '../widgets/layout/feed_right_panel.dart';
import '../widgets/layout/feed_background.dart';
import '../widgets/layout/topbar.dart';
import '../widgets/chat/friend_chat_panel.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;
  String? viewedProfileId;
  Map<String, dynamic>? activeFriendChat;

  Timer? _onlineHeartbeat;
  final _spotify = SpotifyService.instance;

  bool _wasPrivateCall = false;

  @override
  void initState() {
    super.initState();
    ProfileController.instance.loadProfile();
    _startOnlinePresence();
    _spotify.initialize();
    ProfileNavigationService.instance.addListener(_openPublicProfile);
    PostNavigationService.instance.addListener(_openPost);
    _spotify.addListener(_onSpotifyChanged);
    VoiceRoomController.instance.addListener(_onVoiceRoomStateChanged);
  }

  @override
  void dispose() {
    _stopOnlinePresence();
    ProfileNavigationService.instance.removeListener(_openPublicProfile);
    PostNavigationService.instance.removeListener(_openPost);
    _spotify.removeListener(_onSpotifyChanged);
    VoiceRoomController.instance.removeListener(_onVoiceRoomStateChanged);
    super.dispose();
  }

  void _onVoiceRoomStateChanged() {
    if (!mounted) return;
    final vc = VoiceRoomController.instance;

    final error = vc.errorMessage;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de llamada: $error'),
          backgroundColor: const Color(0xffd64a68),
        ),
      );
      vc.clearError();
    }

    if (vc.isPrivateCall && !_wasPrivateCall) {
      _wasPrivateCall = true;
    } else if (!vc.isPrivateCall && _wasPrivateCall) {
      _wasPrivateCall = false;
    }
  }

  void _onSpotifyChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _setOnline(bool online) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({
            'is_online': online,
            'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);
    } catch (_) {}
  }

  void _startOnlinePresence() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _setOnline(true);
    _onlineHeartbeat = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _setOnline(true),
    );

    PresenceController.instance.startPresence();
    VoiceRoomController.instance.listenToPrivateCalls();
  }

  void _stopOnlinePresence() {
    _onlineHeartbeat?.cancel();
    _onlineHeartbeat = null;

    PresenceController.instance.stopPresence();
    _setOnline(false);
  }

  void _openPublicProfile() {
    final profileId = ProfileNavigationService.instance.value;
    if (profileId == null || !mounted) return;
    setState(() {
      selectedIndex = 1;
      viewedProfileId = profileId;
      activeFriendChat = null;
    });
  }

  void _openPost() {
    if (PostNavigationService.instance.postId == null || !mounted) return;
    setState(() {
      selectedIndex = 0;
      viewedProfileId = null;
      activeFriendChat = null;
    });
  }

  Widget currentPage() {
    switch (selectedIndex) {
      case 0:
        return const FeedPage();

      case 1:
        // La key evita reutilizar el estado/FutureBuilder del perfil anterior
        // al navegar muy rápido entre usuarios distintos.
        return ProfilePage(
          key: ValueKey('profile-${viewedProfileId ?? 'me'}'),
          userId: viewedProfileId,
        );

      case 2:
        return const FriendsPage();

      case 3:
        return const VoiceChannelsPage();

      case 4:
        return const TournamentsPage();

      case 5:
        return const Center(
          child: Text(
            "Ajustes",
            style: TextStyle(color: Colors.white, fontSize: 30),
          ),
        );

      default:
        return const FeedPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff17141F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (selectedIndex == 0 || selectedIndex == 1 || selectedIndex == 3)
            const FeedBackground(),
          Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 250,
                      child: Sidebar(
                        selected: selectedIndex,
                        onSelected: (index) {
                          setState(() {
                            selectedIndex = index;
                            viewedProfileId = null;
                            if (index != 2) activeFriendChat = null;
                          });
                          ProfileNavigationService.instance.clear();
                        },
                      ),
                    ),
                    Expanded(
                      child: selectedIndex == 2
                          ? _friendsLayout()
                          : _standardLayout(),
                    ),
                    if (selectedIndex != 2)
                      SizedBox(
                        width: selectedIndex == 0 ? 310 : 280,
                        child: viewedProfileId == null
                            ? (selectedIndex == 0
                                  ? FeedRightPanel(
                                      onOpenChat: (profile) {
                                        setState(() {
                                          selectedIndex = 2;
                                          activeFriendChat = profile;
                                        });
                                      },
                                    )
                                  : const MyProfilePanel())
                            : PublicProfilePanel(
                                key: ValueKey('public-panel-$viewedProfileId'),
                                userId: viewedProfileId!,
                              ),
                      ),
                  ],
                ),
              ),
              ListenableBuilder(
                listenable: VoiceRoomController.instance,
                builder: (context, _) {
                  final vc = VoiceRoomController.instance;
                  if (!vc.isConnected) return const SizedBox.shrink();
                  return _VoiceBar(
                    controller: vc,
                    onGoToChannel: () => setState(() => selectedIndex = 3),
                    onMaximizeCall: vc.maximize,
                  );
                },
              ),
            ],
          ),
          ListenableBuilder(
            listenable: VoiceRoomController.instance,
            builder: (context, _) {
              final vc = VoiceRoomController.instance;
              if (vc.isIncomingRinging && vc.callingUserProfile != null) {
                return _buildIncomingCallOverlay(vc);
              }
              if (vc.isOutgoingRinging && vc.callingUserProfile != null) {
                return _buildOutgoingCallOverlay(vc);
              }
              if (vc.isPrivateCall && !vc.isMinimized && vc.privateCallUser != null) {
                return _buildActiveCallOverlay(vc);
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCallOverlay(VoiceRoomController vc) {
    if (vc.isMinimized) return const SizedBox.shrink();

    final user = vc.privateCallUser;
    if (user == null) return const SizedBox.shrink();

    final name = (user['username'] ?? user['name'] ?? 'Usuario').toString();
    final avatar = user['avatar_url']?.toString() ?? '';

    // Obtener estado de conexión
    String statusText = 'Conectando...';
    if (vc.status == VoiceConnectionStatus.connected) {
      statusText = 'En llamada';
    } else if (vc.status == VoiceConnectionStatus.reconnecting) {
      statusText = 'Reconectando...';
    } else if (vc.status == VoiceConnectionStatus.error) {
      statusText = 'Error de conexión';
    }

    // Buscar si el otro participante tiene el micrófono silenciado
    bool isOtherMuted = true;
    if (vc.participants.isNotEmpty) {
      final otherPart = vc.participants.firstWhere(
        (p) => p.id != Supabase.instance.client.auth.currentUser?.id,
        orElse: () => vc.participants.first,
      );
      isOtherMuted = otherPart.isMuted;
    }

    final isSpeaking = vc.activeSpeakerId == user['id']?.toString();
    final durationStr = vc.durationFormatted;

    return Container(
      color: const Color(0xff0b0913).withOpacity(0.96),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.security_rounded, color: Color(0xff50e6a5), size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'LLAMADA PRIVADA ENCRIPTADA',
                    style: TextStyle(color: Color(0xff50e6a5), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white70, size: 24),
                    onPressed: vc.minimize,
                    tooltip: 'Minimizar llamada',
                  ),
                ],
              ),
            ),
            const Spacer(),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isSpeaking)
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xff8b4dff).withOpacity(0.2),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSpeaking ? const Color(0xff8b4dff) : const Color(0xff3d325e),
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xff6d35f5),
                        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        child: avatar.isEmpty
                            ? Text(
                                name.isEmpty ? '?' : name[0].toUpperCase(),
                                style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                    ),
                    if (isOtherMuted)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xffd64a68),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mic_off_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: vc.status == VoiceConnectionStatus.connected ? const Color(0xff50e6a5) : const Color(0xffffb800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$statusText  ·  $durationStr',
                      style: const TextStyle(color: Color(0xff9a94a8), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xff141121),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xff2d2543)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _callActionBtn(
                    icon: vc.microphoneMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    active: vc.microphoneMuted,
                    color: vc.microphoneMuted ? const Color(0xffd64a68) : const Color(0xff211b33),
                    onTap: vc.toggleMute,
                    tooltip: vc.microphoneMuted ? 'Activar micrófono' : 'Silenciar micrófono',
                  ),
                  _callActionBtn(
                    icon: vc.deafened ? Icons.headset_off_rounded : Icons.headphones_rounded,
                    active: vc.deafened,
                    color: vc.deafened ? const Color(0xffd64a68) : const Color(0xff211b33),
                    onTap: vc.toggleDeafen,
                    tooltip: vc.deafened ? 'Activar sonido' : 'Silenciar sonido',
                  ),
                  _callActionBtn(
                    icon: vc.isScreenSharing ? Icons.screen_share_rounded : Icons.stop_screen_share_rounded,
                    active: vc.isScreenSharing,
                    color: vc.isScreenSharing ? const Color(0xff50e6a5) : const Color(0xff211b33),
                    onTap: vc.toggleScreenShare,
                    tooltip: vc.isScreenSharing ? 'Detener transmisión' : 'Compartir pantalla',
                  ),
                  const SizedBox(width: 12),
                  _callActionBtn(
                    icon: Icons.call_end_rounded,
                    active: true,
                    color: const Color(0xffd64a68),
                    onTap: vc.endPrivateCall,
                    tooltip: 'Colgar llamada',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _callActionBtn({
    required IconData icon,
    required bool active,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildIncomingCallOverlay(VoiceRoomController vc) {
    final user = vc.callingUserProfile!;
    final name = (user['username'] ?? user['name'] ?? 'Usuario').toString();
    final avatar = user['avatar_url']?.toString() ?? '';

    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xff1b1625),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xff3d325e)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xff6d35f5),
                backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                child: avatar.isEmpty
                    ? Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Llamada entrante...',
                style: TextStyle(color: Color(0xff9a94a8), fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: vc.rejectPrivateCall,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffd64a68), foregroundColor: Colors.white),
                    icon: const Icon(Icons.call_end_rounded),
                    label: const Text('Rechazar'),
                  ),
                  ElevatedButton.icon(
                    onPressed: vc.acceptPrivateCall,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff50e6a5), foregroundColor: Colors.white),
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Aceptar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutgoingCallOverlay(VoiceRoomController vc) {
    final user = vc.callingUserProfile!;
    final name = (user['username'] ?? user['name'] ?? 'Usuario').toString();
    final avatar = user['avatar_url']?.toString() ?? '';

    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xff1b1625),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xff3d325e)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xff6d35f5),
                backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                child: avatar.isEmpty
                    ? Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Llamando...',
                style: TextStyle(color: Color(0xff9a94a8), fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: vc.endPrivateCall,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffd64a68), foregroundColor: Colors.white),
                icon: const Icon(Icons.call_end_rounded),
                label: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() =>
      TopBar(onProfileSelected: ProfileNavigationService.instance.openProfile);

  Widget _standardLayout() => Column(
    children: [
      _topBar(),
      Expanded(child: currentPage()),
    ],
  );

  Widget _friendsLayout() => Row(
    children: [
      Expanded(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: FriendsPage(
                showChat: false,
                onFriendSelected: (profile) =>
                    setState(() => activeFriendChat = profile),
              ),
            ),
          ],
        ),
      ),
      SizedBox(
        width: 370,
        child: FriendChatPanel(
          profile: activeFriendChat,
          onClose: () => setState(() => activeFriendChat = null),
        ),
      ),
    ],
  );
}

class _SpotifyMiniPlayer extends StatefulWidget {
  const _SpotifyMiniPlayer({required this.spotify});

  final SpotifyService spotify;
  static const _spotifyGreen = Color(0xff1ED760);

  @override
  State<_SpotifyMiniPlayer> createState() => _SpotifyMiniPlayerState();
}

class _SpotifyMiniPlayerState extends State<_SpotifyMiniPlayer> {
  static bool _isExpanded = false;

  double _progress(SpotifyPlayback? track) {
    final duration = track?.durationMs ?? 0;
    if (duration <= 0) return 0;
    return ((track?.positionMs ?? 0) / duration).clamp(0, 1).toDouble();
  }

  String _time(int? milliseconds) {
    final seconds = (milliseconds ?? 0) ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.spotify.playback;
    final isConnected = widget.spotify.isConnected;
    final isPlaying = track != null && track.isPlaying;

    // Si no se está reproduciendo música, forzar a estar colapsado (altura 50 px)
    final showExpanded = _isExpanded && isPlaying;
    final height = showExpanded ? 72.0 : 50.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Color(0xff120F19),
        border: Border(top: BorderSide(color: Color(0xff3A2E4B))),
      ),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              Container(
                width: showExpanded ? 46 : 38,
                height: showExpanded ? 46 : 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  color: const Color(0xff30253E),
                ),
                clipBehavior: Clip.antiAlias,
                child: track?.artworkUrl == null
                    ? const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 20)
                    : Image.network(track!.artworkUrl!, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track?.title ??
                          (isConnected
                              ? 'Sin reproducción activa'
                              : 'Conecta Spotify'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      track?.artist ??
                          (isConnected
                              ? 'Reproduce una canción en Spotify'
                              : 'Escucha tu música aquí'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xff9D96A7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (!showExpanded) ...[
                const Spacer(),
                if (isPlaying) ...[
                  IconButton(
                    tooltip: 'Pausar',
                    onPressed: isConnected ? widget.spotify.togglePlayback : null,
                    icon: const Icon(Icons.pause_circle_filled_rounded),
                    iconSize: 32,
                    color: Colors.white,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Expandir reproductor',
                    onPressed: () => setState(() => _isExpanded = true),
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    color: const Color(0xffD4CFDA),
                    iconSize: 26,
                    padding: EdgeInsets.zero,
                  ),
                ] else ...[
                  const Icon(Icons.music_note_rounded, color: _SpotifyMiniPlayer._spotifyGreen, size: 18),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: isConnected ? widget.spotify.openSpotify : widget.spotify.connect,
                    child: Text(
                      isConnected ? 'Abrir Spotify' : 'Conectar Spotify',
                      style: const TextStyle(
                        color: _SpotifyMiniPlayer._spotifyGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ] else ...[
                IconButton(
                  tooltip: 'Canción anterior',
                  onPressed: isConnected ? widget.spotify.previous : null,
                  icon: const Icon(Icons.skip_previous_rounded),
                  color: const Color(0xffD4CFDA),
                ),
                IconButton(
                  tooltip: track?.isPlaying == true ? 'Pausar' : 'Reproducir',
                  onPressed: isConnected ? widget.spotify.togglePlayback : null,
                  icon: Icon(
                    track?.isPlaying == true
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                  ),
                  iconSize: 38,
                  color: Colors.white,
                ),
                IconButton(
                  tooltip: 'Siguiente canción',
                  onPressed: isConnected ? widget.spotify.next : null,
                  icon: const Icon(Icons.skip_next_rounded),
                  color: const Color(0xffD4CFDA),
                ),
                IconButton(
                  tooltip: 'Aleatorio de tus me gusta',
                  onPressed: isConnected ? widget.spotify.playRandomLikedTrack : null,
                  icon: const Icon(Icons.shuffle_rounded),
                  color: const Color(0xffD4CFDA),
                ),
                IconButton(
                  tooltip: 'Ver cola',
                  onPressed: isConnected
                      ? () => showDialog(
                          context: context,
                          builder: (_) => SpotifyQueueDialog(spotify: widget.spotify),
                        )
                      : null,
                  icon: Badge(
                    isLabelVisible: widget.spotify.queue.isNotEmpty,
                    label: Text('${widget.spotify.queue.length}'),
                    child: const Icon(Icons.queue_music_rounded),
                  ),
                  color: const Color(0xffD4CFDA),
                ),
                IconButton(
                  tooltip: widget.spotify.jamUrl == null
                      ? 'Añadir Spotify Jam'
                      : 'Abrir Spotify Jam',
                  onPressed: isConnected
                      ? () => widget.spotify.jamUrl == null
                            ? showDialog(
                                context: context,
                                builder: (_) => SpotifyJamDialog(spotify: widget.spotify),
                              )
                            : widget.spotify.openJam()
                      : null,
                  icon: Icon(
                    widget.spotify.jamUrl == null
                        ? Icons.group_add_rounded
                        : Icons.groups_rounded,
                  ),
                  color: const Color(0xffD4CFDA),
                ),
                IconButton(
                  tooltip: 'Buscar canción',
                  onPressed: isConnected
                      ? () => showDialog(
                          context: context,
                          builder: (_) => SpotifySearchDialog(spotify: widget.spotify),
                        )
                      : null,
                  icon: const Icon(Icons.search_rounded),
                  color: const Color(0xffD4CFDA),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        _time(track?.positionMs),
                        style: const TextStyle(
                          color: Color(0xff9D96A7),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 3,
                          child: LinearProgressIndicator(
                            value: _progress(track),
                            backgroundColor: const Color(0xff3D3548),
                            valueColor: const AlwaysStoppedAnimation(_SpotifyMiniPlayer._spotifyGreen),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _time(track?.durationMs),
                        style: const TextStyle(
                          color: Color(0xff9D96A7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                const Icon(
                  Icons.volume_up_rounded,
                  color: Color(0xffD4CFDA),
                  size: 19,
                ),
                SizedBox(
                  width: 82,
                  child: Slider(
                    value: widget.spotify.volume,
                    activeColor: _SpotifyMiniPlayer._spotifyGreen,
                    onChanged: isConnected ? widget.spotify.setVolume : null,
                  ),
                ),
                const Icon(Icons.music_note_rounded, color: _SpotifyMiniPlayer._spotifyGreen, size: 20),
                const SizedBox(width: 5),
                TextButton(
                  onPressed: isConnected ? widget.spotify.openSpotify : widget.spotify.connect,
                  child: Text(
                    isConnected ? 'Abrir Spotify' : 'Conectar Spotify',
                    style: const TextStyle(
                      color: _SpotifyMiniPlayer._spotifyGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Colapsar reproductor',
                  onPressed: () => setState(() => _isExpanded = false),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  color: const Color(0xffD4CFDA),
                  iconSize: 26,
                  padding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SpotifySearchDialog extends StatefulWidget {
  const SpotifySearchDialog({required this.spotify});
  final SpotifyService spotify;

  @override
  State<SpotifySearchDialog> createState() => SpotifySearchDialogState();
}

class SpotifySearchDialogState extends State<SpotifySearchDialog> {
  final _controller = TextEditingController();
  List<SpotifyTrackResult> _results = [];
  bool _loading = false;

  Future<void> _search() async {
    setState(() => _loading = true);
    final results = await widget.spotify.searchTracks(_controller.text);
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xff1B1625),
    title: const Text('Buscar en Spotify'),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Canción o artista',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _search,
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(),
            ),
          SizedBox(
            height: 280,
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (_, index) {
                final track = _results[index];
                return ListTile(
                  leading: track.artworkUrl == null
                      ? const Icon(Icons.music_note)
                      : Image.network(
                          track.artworkUrl!,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                        ),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Añadir a la cola',
                        onPressed: () => widget.spotify.addToQueue(track),
                        icon: const Icon(Icons.playlist_add_rounded),
                      ),
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        color: _SpotifyMiniPlayer._spotifyGreen,
                      ),
                    ],
                  ),
                  onTap: () {
                    widget.spotify.playTrack(track);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class SpotifyQueueDialog extends StatelessWidget {
  const SpotifyQueueDialog({required this.spotify});
  final SpotifyService spotify;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xff1B1625),
    title: const Text('Próximamente en cola'),
    content: SizedBox(
      width: 420,
      height: 280,
      child: spotify.queue.isEmpty
          ? const Center(
              child: Text(
                'La cola está vacía. Busca canciones para añadirlas.',
              ),
            )
          : ListView.builder(
              itemCount: spotify.queue.length,
              itemBuilder: (_, index) {
                final track = spotify.queue[index];
                return ListTile(
                  leading: track.artworkUrl == null
                      ? const Icon(Icons.music_note)
                      : Image.network(
                          track.artworkUrl!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                  title: Text(track.title),
                  subtitle: Text(track.artist),
                );
              },
            ),
    ),
  );
}

class SpotifyJamDialog extends StatefulWidget {
  const SpotifyJamDialog({required this.spotify});
  final SpotifyService spotify;

  @override
  State<SpotifyJamDialog> createState() => SpotifyJamDialogState();
}

class SpotifyJamDialogState extends State<SpotifyJamDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xff1B1625),
    title: const Text('Invitar a una Spotify Jam'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Crea la Jam desde Spotify, pega aquí su enlace y compártelo con tus amigos.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'https://open.spotify.com/jam/...',
              errorText: _error,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () async {
          final valid = await widget.spotify.setJamUrl(_controller.text);
          if (!mounted) return;
          if (!valid) {
            setState(() => _error = 'El enlace no parece ser de Spotify.');
            return;
          }
          await Clipboard.setData(ClipboardData(text: widget.spotify.jamUrl!));
          if (mounted) Navigator.pop(context);
        },
        child: const Text('Guardar y copiar'),
      ),
    ],
  );
}

class _VoiceBar extends StatelessWidget {
  const _VoiceBar({
    required this.controller,
    required this.onGoToChannel,
    required this.onMaximizeCall,
  });

  final VoiceRoomController controller;
  final VoidCallback onGoToChannel;
  final VoidCallback onMaximizeCall;

  static const _green = Color(0xff50E6A5);
  static const _red = Color(0xffD64A68);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: controller.isPrivateCall ? onMaximizeCall : onGoToChannel,
      child: Container(
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xff171323),
          border: Border(top: BorderSide(color: Color(0xff49306B))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              controller.isPrivateCall
                  ? 'Llamada con ${controller.privateCallUser?['username'] ?? 'Usuario'}'
                  : 'Voz conectada',
              style: const TextStyle(
                color: _green,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!controller.isPrivateCall) ...[
              const SizedBox(width: 4),
              const Text(
                '· Toca para ir al canal',
                style: TextStyle(color: Color(0xff8D8797), fontSize: 12),
              ),
            ],
            const Spacer(),
            _BarButton(
              icon: controller.microphoneMuted
                  ? Icons.mic_off_rounded
                  : Icons.mic_rounded,
              active: controller.microphoneMuted,
              tooltip: controller.microphoneMuted
                  ? 'Activar micro'
                  : 'Silenciar',
              onTap: controller.toggleMute,
            ),
            const SizedBox(width: 4),
            _BarButton(
              icon: controller.deafened
                  ? Icons.headset_off_rounded
                  : Icons.headphones_rounded,
              active: controller.deafened,
              tooltip: controller.deafened ? 'Escuchar' : 'Silenciar audio',
              onTap: controller.toggleDeafen,
            ),
            const SizedBox(width: 4),
            _BarButton(
              icon: Icons.call_end_rounded,
              active: true,
              color: _red,
              tooltip: controller.isPrivateCall ? 'Colgar llamada' : 'Salir del canal',
              onTap: () => controller.isPrivateCall ? controller.endPrivateCall() : controller.leaveRoom(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.active,
    required this.onTap,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c =
        color ?? (active ? const Color(0xffD64A68) : const Color(0xff9A94A8));
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: c, size: 18),
        ),
      ),
    );
  }
}
