import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/voice_room_controller.dart';
import '../pages/feed_page.dart';
import '../pages/profile_page.dart';
import '../pages/friends_page.dart';
import '../pages/voice_channels_page.dart';
import '../services/profile_navigation_service.dart';
import '../services/post_navigation_service.dart';

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

  @override
  void initState() {
    super.initState();
    cargarUsuario();
    _startOnlinePresence();
    ProfileNavigationService.instance.addListener(_openPublicProfile);
    PostNavigationService.instance.addListener(_openPost);
  }

  @override
  void dispose() {
    _stopOnlinePresence();
    ProfileNavigationService.instance.removeListener(_openPublicProfile);
    PostNavigationService.instance.removeListener(_openPost);
    super.dispose();
  }

  Future<void> _setOnline(bool online) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client.from('profiles').update({
        'is_online': online,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
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
              tooltip: controller.microphoneMuted ? 'Activar micro' : 'Silenciar',
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
    final c = color ?? (active ? const Color(0xffD64A68) : const Color(0xff9A94A8));
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
