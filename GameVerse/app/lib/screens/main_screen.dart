import 'package:flutter/material.dart';

import '../pages/feed_page.dart';
import '../pages/friends_page.dart';

import '../widgets/layout/sidebar.dart';
import '../widgets/layout/right_panel.dart';
import '../widgets/layout/topbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;
  String usernameActual = "Usuario";
  @override
  void initState() {
    super.initState();
    cargarUsuario();
  }

  Future<void> cargarUsuario() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    print("USUARIO LOGIN: $user");

    final data = await Supabase.instance.client
        .from('profiles')
        .select('username')
        .eq('id', user.id)
        .single();

    setState(() {
      usernameActual = data['username'] ?? "Sin nombre";
    });
  }

  Widget currentPage() {
    switch (selectedIndex) {
      case 0:
        return const FeedPage();

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
          // SIDEBAR IZQUIERDO
          SizedBox(
            width: 250,

            child: Sidebar(
              selected: selectedIndex,
              username: usernameActual,

              onSelected: (index) {
                setState(() {
                  selectedIndex = index;
                });
              },
            ),
          ),

          // CENTRO
          Expanded(
            child: Column(
              children: [
                const TopBar(),

                Expanded(
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 760),

                      child: currentPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // PANEL DERECHO
          SizedBox(width: 280, child: const RightPanel()),
        ],
      ),
    );
  }
}
