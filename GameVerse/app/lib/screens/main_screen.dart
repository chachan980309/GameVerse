import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/feed_page.dart';
import '../pages/profile_page.dart';
import '../pages/friends_page.dart';
import '../services/profile_navigation_service.dart';
import '../services/post_navigation_service.dart';

import '../widgets/layout/sidebar.dart';
import '../widgets/layout/right_panel.dart';
import '../widgets/layout/feed_right_panel.dart';
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

  @override
  void initState() {
    super.initState();
    cargarUsuario();
    ProfileNavigationService.instance.addListener(_openPublicProfile);
    PostNavigationService.instance.addListener(_openPost);
  }

  @override
  void dispose() {
    ProfileNavigationService.instance.removeListener(_openPublicProfile);
    PostNavigationService.instance.removeListener(_openPost);
    super.dispose();
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
        return const Center(
          child: Text(
            "Chats",
            style: TextStyle(color: Colors.white, fontSize: 30),
          ),
        );

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
      body: Row(
        children: [
          SizedBox(
            width: 250,
            child: Sidebar(
              selected: selectedIndex,
              username: usernameActual,
              onSelected: (index) {
                setState(() {
                  selectedIndex = index;
                  // Sidebar navigation returns to the user's own profile/panels.
                  viewedProfileId = null;
                  if (index != 2) activeFriendChat = null;
                });
                ProfileNavigationService.instance.clear();
              },
            ),
          ),

          Expanded(
            child: selectedIndex == 2 ? _friendsLayout() : _standardLayout(),
          ),

          if (selectedIndex != 2)
            SizedBox(
              width: selectedIndex == 0 ? 310 : 280,
              child: viewedProfileId == null
                  ? (selectedIndex == 0
                        ? const FeedRightPanel()
                        : const MyProfilePanel())
                  : PublicProfilePanel(
                      key: ValueKey('public-panel-$viewedProfileId'),
                      userId: viewedProfileId!,
                    ),
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
