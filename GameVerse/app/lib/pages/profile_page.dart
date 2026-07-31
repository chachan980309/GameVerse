import 'package:flutter/material.dart';

import 'profile/tabs/wall_tab.dart';
import 'profile/tabs/games_tab.dart';
import 'profile/tabs/clips_tab.dart';
import 'profile/tabs/photos_tab.dart';

import '../../widgets/profile/profile_header.dart';
import '../../widgets/profile/profile_overview.dart';
import '../../widgets/profile/profile_tabs.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff17141F),
      body: SafeArea(
        child: Column(
          children: [
            // ==========================
            // BANNER
            // ==========================
            const ProfileHeader(),

            const SizedBox(height: 12),

            // ==========================
            // OVERVIEW DEL PERFIL
            // ==========================
            const ProfileOverview(),

            const SizedBox(height: 12),

            // ==========================
            // TABS
            // ==========================
            ProfileTabs(
              selectedIndex: _selectedTab,
              onTabSelected: (index) {
                setState(() {
                  _selectedTab = index;
                });
              },
            ),

            // ==========================
            // CONTENIDO
            // ==========================
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: const [
                  WallTab(),
                  GamesTab(),
                  ClipsTab(),
                  PhotosTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
