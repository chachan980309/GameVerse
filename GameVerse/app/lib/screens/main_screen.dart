import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/voice_room_controller.dart';
import '../pages/feed_page.dart';
import '../pages/profile_page.dart';
import '../pages/friends_page.dart';
import '../pages/voice_channels_page.dart';
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

  String usernameActual = "Usuario";
  Timer? _onlineHeartbeat;
  final _spotify = SpotifyService.instance;

  @override
  void initState() {
    super.initState();
    cargarUsuario();
    _startOnlinePresence();
    _spotify.initialize();
    ProfileNavigationService.instance.addListener(_openPublicProfile);
    PostNavigationService.instance.addListener(_openPost);
    _spotify.addListener(_onSpotifyChanged);
  }

  @override
  void dispose() {
    _stopOnlinePresence();
    ProfileNavigationService.instance.removeListener(_openPublicProfile);
    PostNavigationService.instance.removeListener(_openPost);
    _spotify.removeListener(_onSpotifyChanged);
    super.dispose();
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
    _setOnline(true);
    _onlineHeartbeat = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _setOnline(true),
    );
  }

  void _stopOnlinePresence() {
    _onlineHeartbeat?.cancel();
    _onlineHeartbeat = null;
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

  Future<void> cargarUsuario() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    final data = await Supabase.instance.client
        .from('profiles')
        .select('username')
        .eq('id', user.id)
        .single();

    if (!mounted) return;

    setState(() {
      usernameActual = data['username'] ?? "Sin nombre";
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
                        username: usernameActual,
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
                  );
                },
              ),
              _SpotifyMiniPlayer(spotify: _spotify),
            ],
          ),
        ],
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

class _SpotifyMiniPlayer extends StatelessWidget {
  const _SpotifyMiniPlayer({required this.spotify});

  final SpotifyService spotify;

  static const _spotifyGreen = Color(0xff1ED760);

  @override
  Widget build(BuildContext context) {
    final track = spotify.playback;
    final isConnected = spotify.isConnected;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Color(0xff120F19),
        border: Border(top: BorderSide(color: Color(0xff3A2E4B))),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              color: const Color(0xff30253E),
            ),
            clipBehavior: Clip.antiAlias,
            child: track?.artworkUrl == null
                ? const Icon(Icons.graphic_eq_rounded, color: Colors.white)
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
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  track?.artist ??
                      (isConnected
                          ? 'Reproduce una canción en Spotify'
                          : 'Escucha tu música aquí'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xff9D96A7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Canción anterior',
            onPressed: isConnected ? spotify.previous : null,
            icon: const Icon(Icons.skip_previous_rounded),
            color: const Color(0xffD4CFDA),
          ),
          IconButton(
            tooltip: track?.isPlaying == true ? 'Pausar' : 'Reproducir',
            onPressed: isConnected ? spotify.togglePlayback : null,
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
            onPressed: isConnected ? spotify.next : null,
            icon: const Icon(Icons.skip_next_rounded),
            color: const Color(0xffD4CFDA),
          ),
          IconButton(
            tooltip: 'Aleatorio de tus me gusta',
            onPressed: isConnected ? spotify.playRandomLikedTrack : null,
            icon: const Icon(Icons.shuffle_rounded),
            color: const Color(0xffD4CFDA),
          ),
          IconButton(
            tooltip: 'Ver cola',
            onPressed: isConnected
                ? () => showDialog(
                    context: context,
                    builder: (_) => _SpotifyQueueDialog(spotify: spotify),
                  )
                : null,
            icon: Badge(
              isLabelVisible: spotify.queue.isNotEmpty,
              label: Text('${spotify.queue.length}'),
              child: const Icon(Icons.queue_music_rounded),
            ),
            color: const Color(0xffD4CFDA),
          ),
          IconButton(
            tooltip: spotify.jamUrl == null
                ? 'Añadir Spotify Jam'
                : 'Abrir Spotify Jam',
            onPressed: isConnected
                ? () => spotify.jamUrl == null
                      ? showDialog(
                          context: context,
                          builder: (_) => _SpotifyJamDialog(spotify: spotify),
                        )
                      : spotify.openJam()
                : null,
            icon: Icon(
              spotify.jamUrl == null
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
                    builder: (_) => _SpotifySearchDialog(spotify: spotify),
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
                      valueColor: const AlwaysStoppedAnimation(_spotifyGreen),
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
              value: spotify.volume,
              activeColor: _spotifyGreen,
              onChanged: isConnected ? spotify.setVolume : null,
            ),
          ),
          const Icon(Icons.music_note_rounded, color: _spotifyGreen, size: 20),
          const SizedBox(width: 5),
          TextButton(
            onPressed: isConnected ? spotify.openSpotify : spotify.connect,
            child: Text(
              isConnected ? 'Abrir Spotify' : 'Conectar Spotify',
              style: const TextStyle(
                color: _spotifyGreen,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _progress(SpotifyPlayback? track) {
    final duration = track?.durationMs ?? 0;
    if (duration <= 0) return 0;
    return ((track?.positionMs ?? 0) / duration).clamp(0, 1).toDouble();
  }

  String _time(int? milliseconds) {
    final seconds = (milliseconds ?? 0) ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

class _SpotifySearchDialog extends StatefulWidget {
  const _SpotifySearchDialog({required this.spotify});
  final SpotifyService spotify;

  @override
  State<_SpotifySearchDialog> createState() => _SpotifySearchDialogState();
}

class _SpotifySearchDialogState extends State<_SpotifySearchDialog> {
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

class _SpotifyQueueDialog extends StatelessWidget {
  const _SpotifyQueueDialog({required this.spotify});
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

class _SpotifyJamDialog extends StatefulWidget {
  const _SpotifyJamDialog({required this.spotify});
  final SpotifyService spotify;

  @override
  State<_SpotifyJamDialog> createState() => _SpotifyJamDialogState();
}

class _SpotifyJamDialogState extends State<_SpotifyJamDialog> {
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
  const _VoiceBar({required this.controller, required this.onGoToChannel});

  final VoiceRoomController controller;
  final VoidCallback onGoToChannel;

  static const _green = Color(0xff50E6A5);
  static const _red = Color(0xffD64A68);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onGoToChannel,
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
            const Text(
              'Voz conectada',
              style: TextStyle(
                color: _green,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '· Toca para ir al canal',
              style: TextStyle(color: Color(0xff8D8797), fontSize: 12),
            ),
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
              tooltip: 'Salir del canal',
              onTap: () => controller.leaveRoom(),
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
