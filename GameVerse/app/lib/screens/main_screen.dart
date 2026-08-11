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
import '../pages/clans_page.dart';
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

  Timer? _onlineHeartbeat;

  bool _wasPrivateCall = false;

  @override
  void initState() {
    super.initState();
    ProfileController.instance.loadProfile();
    _startOnlinePresence();
    ProfileNavigationService.instance.addListener(_openPublicProfile);
    PostNavigationService.instance.addListener(_openPost);
    VoiceRoomController.instance.addListener(_onVoiceRoomStateChanged);
  }

  @override
  void dispose() {
    _stopOnlinePresence();
    ProfileNavigationService.instance.removeListener(_openPublicProfile);
    PostNavigationService.instance.removeListener(_openPost);
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
    VoiceRoomController.instance.initVoicePresence();
  }

  void _stopOnlinePresence() {
    _onlineHeartbeat?.cancel();
    _onlineHeartbeat = null;

    PresenceController.instance.stopPresence();
    VoiceRoomController.instance.stopVoicePresence();
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
        return const ClansPage();

      case 6:
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
          if (selectedIndex == 0 ||
              selectedIndex == 1 ||
              selectedIndex == 3 ||
              selectedIndex == 5)
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
              if (vc.isPrivateCall &&
                  !vc.isMinimized &&
                  vc.privateCallUser != null) {
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
                  const Icon(
                    Icons.security_rounded,
                    color: Color(0xff50e6a5),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'LLAMADA PRIVADA ENCRIPTADA',
                    style: TextStyle(
                      color: Color(0xff50e6a5),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.fullscreen_exit_rounded,
                      color: Colors.white70,
                      size: 24,
                    ),
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
                          color: isSpeaking
                              ? const Color(0xff8b4dff)
                              : const Color(0xff3d325e),
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xff6d35f5),
                        backgroundImage: avatar.isNotEmpty
                            ? NetworkImage(avatar)
                            : null,
                        child: avatar.isEmpty
                            ? Text(
                                name.isEmpty ? '?' : name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 32,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
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
                          child: const Icon(
                            Icons.mic_off_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
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
                        color: vc.status == VoiceConnectionStatus.connected
                            ? const Color(0xff50e6a5)
                            : const Color(0xffffb800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$statusText  ·  $durationStr',
                      style: const TextStyle(
                        color: Color(0xff9a94a8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
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
                    icon: vc.microphoneMuted
                        ? Icons.mic_off_rounded
                        : Icons.mic_rounded,
                    active: vc.microphoneMuted,
                    color: vc.microphoneMuted
                        ? const Color(0xffd64a68)
                        : const Color(0xff211b33),
                    onTap: vc.toggleMute,
                    tooltip: vc.microphoneMuted
                        ? 'Activar micrófono'
                        : 'Silenciar micrófono',
                  ),
                  _callActionBtn(
                    icon: vc.deafened
                        ? Icons.headset_off_rounded
                        : Icons.headphones_rounded,
                    active: vc.deafened,
                    color: vc.deafened
                        ? const Color(0xffd64a68)
                        : const Color(0xff211b33),
                    onTap: vc.toggleDeafen,
                    tooltip: vc.deafened
                        ? 'Activar sonido'
                        : 'Silenciar sonido',
                  ),
                  _callActionBtn(
                    icon: vc.isScreenSharing
                        ? Icons.screen_share_rounded
                        : Icons.stop_screen_share_rounded,
                    active: vc.isScreenSharing,
                    color: vc.isScreenSharing
                        ? const Color(0xff50e6a5)
                        : const Color(0xff211b33),
                    onTap: vc.toggleScreenShare,
                    tooltip: vc.isScreenSharing
                        ? 'Detener transmisión'
                        : 'Compartir pantalla',
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
                backgroundImage: avatar.isNotEmpty
                    ? NetworkImage(avatar)
                    : null,
                child: avatar.isEmpty
                    ? Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffd64a68),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.call_end_rounded),
                    label: const Text('Rechazar'),
                  ),
                  ElevatedButton.icon(
                    onPressed: vc.acceptPrivateCall,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff50e6a5),
                      foregroundColor: Colors.white,
                    ),
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
                backgroundImage: avatar.isNotEmpty
                    ? NetworkImage(avatar)
                    : null,
                child: avatar.isEmpty
                    ? Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Llamando...',
                style: TextStyle(color: Color(0xff9a94a8), fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: vc.endPrivateCall,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffd64a68),
                  foregroundColor: Colors.white,
                ),
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
              tooltip: controller.isPrivateCall
                  ? 'Colgar llamada'
                  : 'Salir del canal',
              onTap: () => controller.isPrivateCall
                  ? controller.endPrivateCall()
                  : controller.leaveRoom(),
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
