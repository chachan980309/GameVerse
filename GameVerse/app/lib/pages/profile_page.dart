import 'package:app/pages/profile/tabs/clips_tab.dart';
import 'package:app/pages/profile/tabs/games_tab.dart';
import 'package:app/pages/profile/tabs/photos_tab.dart';
import 'package:app/pages/profile/tabs/wall_tab.dart';
import 'package:app/widgets/profile/profile_header.dart';
import 'package:app/widgets/profile/profile_tabs.dart';
import 'package:flutter/material.dart';

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
      body: SingleChildScrollView(
        child: Column(
          children: [
            const ProfileHeader(),

            ProfileTabs(
              selectedIndex: _selectedTab,
              onTabSelected: (index) {
                setState(() {
                  _selectedTab = index;
                });
              },
            ),

            IndexedStack(
              index: _selectedTab,
              children: const [WallTab(), GamesTab(), ClipsTab(), PhotosTab()],
            ),
          ],
        ),
      ),
    );
  }
}
