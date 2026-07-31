import 'package:flutter/material.dart';

import 'profile/tabs/wall_tab.dart';
import 'profile/tabs/games_tab.dart';
import 'profile/tabs/clips_tab.dart';
import 'profile/tabs/photos_tab.dart';

import '../../widgets/profile/profile_header.dart';
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
            // HEADER PERFIL
            // ==========================
            const SizedBox(height: 270, child: ProfileHeader()),

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
