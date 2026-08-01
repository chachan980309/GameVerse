import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/post_model.dart';
import '../services/post_service.dart';
import '../widgets/profile/profile_header.dart';
import '../widgets/profile/profile_tabs.dart';
import 'profile/tabs/clips_tab.dart';
import 'profile/tabs/games_tab.dart';
import 'profile/tabs/photos_tab.dart';
import 'profile/tabs/wall_tab.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.userId});

  /// A null value renders the authenticated user's existing editable profile.
  final String? userId;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.userId != null) return _PublicProfilePage(userId: widget.userId!);

    return Scaffold(
      backgroundColor: const Color(0xFF17141F),
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 270, child: ProfileHeader()),
          ProfileTabs(
            selectedIndex: _selectedTab,
            onTabSelected: (index) => setState(() => _selectedTab = index),
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: const [WallTab(), GamesTab(), ClipsTab(), PhotosTab()],
            ),
          ),
        ]),
      ),
    );
  }
}

class _PublicProfilePage extends StatefulWidget {
  const _PublicProfilePage({required this.userId});

  final String userId;

  @override
  State<_PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<_PublicProfilePage> {
  late final Future<_PublicProfileData?> _profileData = _loadProfile();

  Future<_PublicProfileData?> _loadProfile() async {
    final rawProfile = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', widget.userId)
        .maybeSingle();
    if (rawProfile == null) return null;

    List<PostModel> posts = [];
    try {
      posts = await PostService().getUserPosts(widget.userId);
    } catch (_) {
      // The public profile remains visible when posts are restricted by RLS.
    }
    return _PublicProfileData(
      profile: Map<String, dynamic>.from(rawProfile),
      posts: posts,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F0E17),
      child: FutureBuilder<_PublicProfileData?>(
        future: _profileData,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(
              child: Text('No pudimos cargar este perfil.', style: TextStyle(color: Colors.white70)),
            );
          }

          final data = snapshot.data!;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _profileHeader(data.profile, data.posts.length),
              _tabs(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                child: _aboutCard(data.profile),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Publicaciones', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (data.posts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: Text('Este usuario aún no tiene publicaciones.', style: TextStyle(color: Colors.white54))),
                    )
                  else
                    ...data.posts.map(_postCard),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _profileHeader(Map<String, dynamic> profile, int postCount) {
    final bannerUrl = profile['banner_url']?.toString() ?? '';
    final avatarUrl = profile['avatar_url']?.toString() ?? '';
    final username = profile['username']?.toString() ?? 'Usuario';
    final status = profile['status']?.toString() ?? '';
    final bio = profile['bio']?.toString() ?? '';
    final online = status.toLowerCase().contains('online') || status.toLowerCase().contains('línea');

    return SizedBox(
      height: 330,
      child: Stack(children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFF111019))),
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          height: 220,
          child: Stack(children: [
            Positioned.fill(
              child: Container(
                color: const Color(0xFF211D2E),
                child: bannerUrl.isEmpty
                    ? null
                    : Image.network(bannerUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [const Color(0xFF111019).withValues(alpha: .9), Colors.transparent],
                  ),
                ),
              ),
            ),
          ]),
        ),
        Positioned(
          left: 28,
          top: 130,
          child: CircleAvatar(
            radius: 70,
            backgroundColor: const Color(0xFF6438FF),
            backgroundImage: avatarUrl.isEmpty ? null : NetworkImage(avatarUrl),
            child: avatarUrl.isEmpty
                ? Text(username.isEmpty ? '?' : username[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 32))
                : null,
          ),
        ),
        Positioned(
          left: 190,
          right: 24,
          top: 182,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(username, style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.bold)),
            if (status.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.circle, size: 10, color: online ? Colors.greenAccent : Colors.white38),
                const SizedBox(width: 6),
                Text(status, style: TextStyle(color: online ? Colors.greenAccent : Colors.white60)),
              ]),
            ],
            if (bio.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(bio, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
            ],
          ]),
        ),
        Positioned(left: 190, top: 292, child: _statChip(Icons.article_outlined, '$postCount publicaciones')),
      ]),
    );
  }

  Widget _tabs() => Container(
        height: 54,
        decoration: const BoxDecoration(
          color: Color(0xFF151420),
          border: Border(bottom: BorderSide(color: Color(0xFF292638))),
        ),
        child: const Row(children: [
          SizedBox(width: 24),
          _ProfileTab(label: 'Muro', selected: true),
          _ProfileTab(label: 'Información'),
        ]),
      );

  Widget _statChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1A29),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFF343044)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: const Color(0xFF9A78FF)),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _aboutCard(Map<String, dynamic> profile) {
    final username = profile['username']?.toString() ?? 'Usuario';
    final bio = profile['bio']?.toString() ?? '';
    final status = profile['status']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171625),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E2A40)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.person_outline, color: Color(0xFF9A78FF), size: 19),
          const SizedBox(width: 8),
          Text('Acerca de $username', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(bio, style: const TextStyle(color: Colors.white70, height: 1.4)),
        ],
        if (status.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(children: [
            const Icon(Icons.circle, size: 10, color: Colors.greenAccent),
            const SizedBox(width: 8),
            Text(status, style: const TextStyle(color: Colors.white60)),
          ]),
        ],
      ]),
    );
  }

  Widget _postCard(PostModel post) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF171625),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2E2A40)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (post.content.isNotEmpty) Text(post.content, style: const TextStyle(color: Colors.white, fontSize: 15)),
          if (post.game != null && post.game!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(post.game!, style: const TextStyle(color: Color(0xFFBDAAFF), fontSize: 12)),
          ],
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.network(post.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
            ),
          ],
        ]),
      );
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
        height: 54,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          border: selected ? const Border(bottom: BorderSide(color: Color(0xFF8B5CF6), width: 3)) : null,
        ),
        child: Text(label, style: TextStyle(color: selected ? const Color(0xFFBDAAFF) : Colors.white60, fontWeight: FontWeight.w600)),
      );
}

class _PublicProfileData {
  const _PublicProfileData({required this.profile, required this.posts});

  final Map<String, dynamic> profile;
  final List<PostModel> posts;
}
