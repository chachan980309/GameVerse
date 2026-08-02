import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/feed_page.dart';
import '../pages/profile_page.dart';
import '../pages/friends_page.dart';

import '../widgets/layout/sidebar.dart';
import '../widgets/layout/right_panel.dart';
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
        return ProfilePage(userId: viewedProfileId);

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
              },
            ),
          ),

          Expanded(child: selectedIndex == 2 ? _friendsLayout() : _standardLayout()),

          if (selectedIndex != 2)
            SizedBox(
              width: 280,
              child: viewedProfileId == null
                  ? (selectedIndex == 1 ? const MyProfilePanel() : const RightPanel())
                  : PublicProfilePanel(userId: viewedProfileId!),
            ),
        ],
      ),
    );
  }

  Widget _topBar() => TopBar(
        onProfileSelected: (profileId) {
          setState(() {
            selectedIndex = 1;
            viewedProfileId = profileId;
            activeFriendChat = null;
          });
        },
      );

  Widget _standardLayout() => Column(children: [
        _topBar(),
        Expanded(child: currentPage()),
      ]);

  Widget _friendsLayout() => Row(children: [
        Expanded(
          child: Column(children: [
            _topBar(),
            Expanded(
              child: FriendsPage(
                showChat: false,
                onFriendSelected: (profile) => setState(() => activeFriendChat = profile),
              ),
            ),
          ]),
        ),
        SizedBox(
          width: 370,
          child: FriendChatPanel(
            profile: activeFriendChat,
            onClose: () => setState(() => activeFriendChat = null),
          ),
        ),
      ]);
}
