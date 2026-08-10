import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/clan_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/voice_room_controller.dart';
import '../models/clan_model.dart';
import '../models/clan_member_model.dart';
import '../models/clan_role_model.dart';
import '../models/clan_event_model.dart';
import '../models/clan_history_model.dart';
import '../models/clan_request_model.dart';
import '../models/post_model.dart';
import '../models/tournament_model.dart';
import '../models/voice_channel.dart';
import '../services/clan_service.dart';
import '../services/post_service.dart';
import '../services/tournament_service.dart';
import '../services/voice_channel_service.dart';
import '../services/image_picker_service.dart';
import '../widgets/tournaments/tournament_card.dart';
import '../widgets/layout/voice_side_panel.dart';

class ClanDetailPage extends StatefulWidget {
  const ClanDetailPage({super.key, required this.clanId});
  final String clanId;

  @override
  State<ClanDetailPage> createState() => _ClanDetailPageState();
}

class _ClanDetailPageState extends State<ClanDetailPage> with SingleTickerProviderStateMixin {
  final ClanController _controller = ClanController.instance;
  late TabController _tabController;

  final ScrollController _historyScrollController = ScrollController();
  final ScrollController _feedScrollController = ScrollController();

  // State local para Feed y Torneos
  List<PostModel> _clanPosts = [];
  bool _loadingPosts = false;
  List<TournamentModel> _clanTournaments = [];
  bool _loadingTournaments = false;

  bool _isChatOpen = false;
  bool _isVoiceConnected = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);

    _controller.loadClanDetail(widget.clanId);
    _loadTabContent(0);

    _historyScrollController.addListener(_onHistoryScroll);

    // Inicializar estado de llamada y agregar listener óptimo
    final vc = VoiceRoomController.instance;
    _isVoiceConnected = vc.isConnected && vc.connectedChannel?.clanId == widget.clanId;
    vc.addListener(_onVoiceConnectionChanged);
  }

  @override
  void dispose() {
    VoiceRoomController.instance.removeListener(_onVoiceConnectionChanged);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _historyScrollController.removeListener(_onHistoryScroll);
    _historyScrollController.dispose();
    _feedScrollController.dispose();
    super.dispose();
  }

  void _onVoiceConnectionChanged() {
    final vc = VoiceRoomController.instance;
    final connected = vc.isConnected && vc.connectedChannel?.clanId == widget.clanId;
    if (connected != _isVoiceConnected) {
      if (mounted) {
        setState(() {
          _isVoiceConnected = connected;
        });
      }
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _loadTabContent(_tabController.index);
    }
  }

  void _onHistoryScroll() {
    if (!_historyScrollController.hasClients) return;
    final threshold = _historyScrollController.position.maxScrollExtent - 200;
    if (_historyScrollController.position.pixels >= threshold) {
      _controller.loadMoreHistory();
    }
  }

  void _loadTabContent(int index) {
    if (index == 0) {
      _loadFeed();
    } else if (index == 2) {
      _loadTournaments();
    }
  }

  Future<void> _loadFeed() async {
    setState(() => _loadingPosts = true);
    try {
      final posts = await PostService().getClanPosts(widget.clanId);
      setState(() => _clanPosts = posts);
    } catch (e) {
      debugPrint('Error loading clan posts: $e');
    } finally {
      setState(() => _loadingPosts = false);
    }
  }

  Future<void> _loadTournaments() async {
    setState(() => _loadingTournaments = true);
    try {
      final list = await TournamentService().fetchTournaments(category: 'all');
      // Filtrar torneos de este clan
      setState(() {
        _clanTournaments = list.where((t) => t.clanId == widget.clanId).toList();
      });
    } catch (e) {
      debugPrint('Error loading clan tournaments: $e');
    } finally {
      setState(() => _loadingTournaments = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff120F1A),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final clan = _controller.selectedClan;
          if (_controller.loadingDetail && clan == null) {
            return const Center(child: CircularProgressIndicator(color: Color(0xff7B4DFF)));
          }

          if (clan == null) {
            return const Center(child: Text('No se pudo cargar el clan.', style: TextStyle(color: Colors.white60)));
          }

          final accent = Color(int.tryParse(clan.accentColor.replaceAll('#', '0xff')) ?? 0xff6438FF);
          final vc = VoiceRoomController.instance;

          return Row(
            children: [
              Expanded(
                child: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverToBoxAdapter(
                        child: _buildBannerHeader(clan, accent),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverTabDelegate(
                          TabBar(
                            controller: _tabController,
                            indicatorColor: accent,
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.white54,
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                            tabs: const [
                              Tab(text: 'Publicaciones Feed 📝'),
                              Tab(text: 'Miembros 👥'),
                              Tab(text: 'Torneos 🏆'),
                              Tab(text: 'Eventos Gremiales 📅'),
                              Tab(text: 'Historial / Actividad 📜'),
                            ],
                          ),
                        ),
                      ),
                    ];
                  },
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFeedTab(clan, accent),
                      _buildMembersTab(clan, accent),
                      _buildTournamentsTab(clan, accent),
                      _buildEventsTab(clan, accent),
                      _buildActivityTab(clan, accent),
                    ],
                  ),
                ),
              ),
              if (_isChatOpen)
                _ClanChatSidePanel(
                  clanId: clan.id,
                  clanName: clan.name,
                  accentColor: accent,
                  onClose: () => setState(() => _isChatOpen = false),
                ),
              ListenableBuilder(
                listenable: vc,
                builder: (context, _) {
                  final isClanVoiceConnected = vc.isConnected && vc.connectedChannel?.clanId == clan.id;
                  if (!isClanVoiceConnected) return const SizedBox.shrink();
                  return VoiceSidePanel(
                    roomName: clan.id,
                    accentColor: accent,
                    controller: vc,
                    members: _controller.selectedClanMembers,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================
  // HEADER
  // ==========================

  Widget _buildBannerHeader(ClanModel clan, Color accent) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = clan.ownerId == userId;
    final isMember = _controller.myClan?.id == clan.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Banner grande
            GestureDetector(
              onTap: isOwner ? _pickBanner : null,
              child: Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                ),
                child: clan.bannerUrl != null && clan.bannerUrl!.isNotEmpty
                    ? Image.network(clan.bannerUrl!, fit: BoxFit.cover)
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accent.withOpacity(0.6), accent.withOpacity(0.1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
              ),
            ),
            Positioned(
              left: 16,
              top: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(12),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            if (isOwner)
              const Positioned(
                right: 16,
                top: 16,
                child: Chip(
                  avatar: Icon(Icons.edit, size: 14, color: Colors.white70),
                  label: Text('Cambiar Banner', style: TextStyle(fontSize: 11)),
                  backgroundColor: Colors.black54,
                ),
              ),

            // Logo superpuesto
            Positioned(
              left: 36,
              bottom: -40,
              child: GestureDetector(
                onTap: isOwner ? _pickLogo : null,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xff120F1A),
                        border: Border.all(color: const Color(0xff120F1A), width: 4),
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: clan.logoUrl != null && clan.logoUrl!.isNotEmpty
                          ? Image.network(clan.logoUrl!, fit: BoxFit.cover)
                          : const Icon(Icons.fort_rounded, color: Colors.white38, size: 48),
                    ),
                    if (isOwner)
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white70, size: 24),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 50),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info del Clan
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          clan.name,
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                        ),
                        if (clan.verified) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.verified, color: Colors.blueAccent, size: 22),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '[${clan.tag}]  ·  Gremio ${clan.clanType == 'competitive' ? 'Competitivo ⚔️' : 'Casual 🎮'}',
                      style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      clan.description.isNotEmpty ? clan.description : 'Sin descripción escrita aún.',
                      style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    _buildProgressionBar(clan, accent),
                  ],
                ),
              ),
              const SizedBox(width: 32),

              // Botones de acción y Stats
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      if (isMember) ...[
                        ElevatedButton.icon(
                          onPressed: _joinVoiceChannel,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700, foregroundColor: Colors.white),
                          icon: const Icon(Icons.volume_up_rounded),
                          label: const Text('Canal de Voz', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _isChatOpen = !_isChatOpen),
                          style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: const Text('Chat Gremio', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ] else ...[
                        _buildJoinOrRequestButton(clan, accent),
                      ],
                      const SizedBox(width: 10),
                      if (isOwner)
                        IconButton(
                          icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                          onPressed: _showEditClanDialog,
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildMiniStats(clan),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildProgressionBar(ClanModel clan, Color accent) {
    final nextLevelXp = 1000;
    final currentXpInLevel = clan.experience % 1000;
    final progress = currentXpInLevel / nextLevelXp;

    return Container(
      width: 420,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xff1B1625), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Nivel del Gremio: ${clan.level}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
              Text('$currentXpInLevel / $nextLevelXp XP', style: const TextStyle(fontSize: 11, color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStats(ClanModel clan) {
    Widget stat(String value, String label) {
      return Container(
        margin: const EdgeInsets.only(left: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xff1B1625), borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
          ],
        ),
      );
    }

    return Row(
      children: [
        stat('${clan.membersCount}', 'Miembros'),
        stat('${clan.tournamentsCreated}', 'Torneos'),
        stat('${clan.eventsHosted}', 'Eventos'),
        stat(clan.region, 'Región'),
      ],
    );
  }

  Widget _buildJoinOrRequestButton(ClanModel clan, Color accent) {
    final hasPending = _controller.myPendingRequest != null;
    return ElevatedButton(
      onPressed: hasPending ? null : () => _controller.joinClan(clan.id),
      style: ElevatedButton.styleFrom(
        backgroundColor: hasPending ? Colors.white10 : accent,
        disabledBackgroundColor: Colors.white10,
      ),
      child: Text(
        hasPending
            ? 'Solicitud Pendiente'
            : (clan.visibility == 'public' ? 'Unirse al Gremio' : 'Solicitar Ingreso'),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: hasPending ? Colors.white38 : Colors.white,
        ),
      ),
    );
  }

  // ==========================
  // FEED TAB
  // ==========================

  Widget _buildFeedTab(ClanModel clan, Color accent) {
    final isMember = _controller.myClan?.id == clan.id;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loadingPosts
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                if (isMember)
                  SliverToBoxAdapter(
                    child: _buildCreatePostHeader(clan, accent),
                  ),
                if (_clanPosts.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.post_add, size: 64, color: Colors.white24),
                          const SizedBox(height: 14),
                          const Text('Aún no hay publicaciones en el feed.', style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final post = _clanPosts[index];
                          return _buildFeedPostCard(post, accent);
                        },
                        childCount: _clanPosts.length,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildCreatePostHeader(ClanModel clan, Color accent) {
    final textController = TextEditingController();
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xff1B1625), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: textController,
              decoration: const InputDecoration(
                hintText: 'Publica algo en el feed exclusivo del clan...',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (textController.text.trim().isEmpty) return;
              await PostService().createPost(
                content: textController.text.trim(),
                clanId: clan.id,
                clanOnly: true,
              );
              _loadFeed();
            },
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: const Text('Publicar'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedPostCard(PostModel post, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xff1B1625), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundImage: post.avatarUrl.isNotEmpty ? NetworkImage(post.avatarUrl) : null,
                radius: 18,
                backgroundColor: accent,
                child: post.avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.username, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('${post.createdAt.day}/${post.createdAt.month} a las ${post.createdAt.hour}:${post.createdAt.minute}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(post.content, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  // ==========================
  // MEMBERS TAB
  // ==========================

  Widget _buildMembersTab(ClanModel clan, Color accent) {
    final canManageMembers = _controller.selectedClanCanManageMembers;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (canManageMembers && _controller.selectedClanRequests.isNotEmpty) ...[
              const Text('📌 Solicitudes Pendientes de Ingreso', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _controller.selectedClanRequests.length,
                itemBuilder: (context, index) {
                  final req = _controller.selectedClanRequests[index];
                  return Card(
                    color: const Color(0xff1B1625),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: req.avatarUrl != null ? NetworkImage(req.avatarUrl!) : null,
                        child: req.avatarUrl == null ? const Icon(Icons.person) : null,
                      ),
                      title: Text(req.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(req.message.isNotEmpty ? req.message : 'Desea unirse al clan.'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.greenAccent),
                            onPressed: () => _controller.handleClanRequest(req.id, 'accepted'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.redAccent),
                            onPressed: () => _controller.handleClanRequest(req.id, 'rejected'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const Divider(color: Colors.white12, height: 32),
            ],

            const Text('👥 Lista de Miembros', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _controller.selectedClanMembers.length,
              itemBuilder: (context, index) {
                final member = _controller.selectedClanMembers[index];
                final isMe = member.userId == Supabase.instance.client.auth.currentUser?.id;
                final roleName = member.role?.name ?? 'Member';

                return Card(
                  color: const Color(0xff1B1625),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
                      child: member.avatarUrl == null ? const Icon(Icons.person) : null,
                    ),
                    title: Row(
                      children: [
                        Text(member.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (isMe) ...[
                          const SizedBox(width: 8),
                          const Chip(label: Text('Tú', style: TextStyle(fontSize: 10)), backgroundColor: Colors.white12),
                        ],
                      ],
                    ),
                    subtitle: Text('Miembro desde: ${member.joinedAt.day}/${member.joinedAt.month}/${member.joinedAt.year}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(roleName),
                          backgroundColor: roleName == 'Leader'
                              ? Colors.amber.withOpacity(0.15)
                              : roleName == 'Co-Leader'
                                  ? Colors.orange.withOpacity(0.15)
                                  : Colors.blueAccent.withOpacity(0.15),
                        ),
                        if (canManageMembers && !isMe && roleName != 'Leader') ...[
                          const SizedBox(width: 10),
                          PopupMenuButton<String>(
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'promote', child: Text('Asignar Rol')),
                              const PopupMenuItem(value: 'kick', child: Text('Expulsar', style: TextStyle(color: Colors.redAccent))),
                            ],
                            onSelected: (val) {
                              if (val == 'kick') {
                                _controller.kickClanMember(member.userId);
                              } else if (val == 'promote') {
                                _showRoleAssignDialog(member);
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRoleAssignDialog(ClanMemberModel member) async {
    final roles = await ClanService.instance.getClanRoles(widget.clanId);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1B1625),
        title: Text('Asignar Rol a ${member.username}'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: roles.length,
            itemBuilder: (context, index) {
              final r = roles[index];
              if (r.name == 'Leader') return const SizedBox.shrink(); // No se puede promover a líder directo aquí
              return ListTile(
                title: Text(r.name),
                subtitle: Text('Nivel de Poder: ${r.level}'),
                onTap: () {
                  _controller.promoteClanMember(member.userId, r.id);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ==========================
  // TOURNAMENTS TAB
  // ==========================

  Widget _buildTournamentsTab(ClanModel clan, Color accent) {
    final canManageTournaments = _controller.selectedClanCanManageTournaments || _controller.selectedClanCanCreateTournaments;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loadingTournaments
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🏆 Torneos de este Clan', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      if (canManageTournaments)
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _showLinkTournamentDialog,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff1C182B)),
                              icon: const Icon(Icons.link),
                              label: const Text('Vincular Torneo'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: _showCreateTournamentDialog,
                              style: ElevatedButton.styleFrom(backgroundColor: accent),
                              icon: const Icon(Icons.add),
                              label: const Text('Crear Torneo'),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_clanTournaments.isEmpty)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          children: [
                            const Icon(Icons.emoji_events, size: 64, color: Colors.white24),
                            const SizedBox(height: 14),
                            const Text('El clan no tiene torneos patrocinados.', style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 360,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.45,
                      ),
                      itemCount: _clanTournaments.length,
                      itemBuilder: (context, index) {
                        final t = _clanTournaments[index];
                        return TournamentCard(tournament: t);
                      },
                    ),
                ],
              ),
            ),
    );
  }

  void _showCreateTournamentDialog() {
    // Para simplificar, abrimos una página o notificamos que debe crearse vinculando el clanId
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Por favor, cree el torneo desde la sección general de Torneos e ingrese el clan organizador.')),
    );
  }

  void _showLinkTournamentDialog() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final allTournaments = await TournamentService().fetchTournaments(category: 'all');
    final myOwned = allTournaments.where((t) => t.creatorId == userId && t.clanId == null).toList();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff1B1625),
        title: const Text('Vincular Torneo Existente'),
        content: SizedBox(
          width: 400,
          child: myOwned.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No tienes torneos activos sin vincular a un clan.', style: TextStyle(color: Colors.white54)),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: myOwned.length,
                  itemBuilder: (context, index) {
                    final t = myOwned[index];
                    return ListTile(
                      title: Text(t.name),
                      subtitle: Text(t.gameName),
                      trailing: const Icon(Icons.link, color: Colors.blueAccent),
                      onTap: () async {
                        await TournamentService().transferOwnershipToClan(t.id, widget.clanId);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        _loadTournaments();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Torneo vinculado con éxito! 🎉')),
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  // ==========================
  // EVENTS TAB
  // ==========================

  Widget _buildEventsTab(ClanModel clan, Color accent) {
    final canCreateEvents = _controller.selectedClanCanCreateEvents || _controller.selectedClanCanManageEvents;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('📅 Calendario de Eventos', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                if (canCreateEvents)
                  ElevatedButton.icon(
                    onPressed: _showCreateEventDialog,
                    style: ElevatedButton.styleFrom(backgroundColor: accent),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Programar Evento'),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (_controller.selectedClanEvents.isEmpty)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    children: [
                      const Icon(Icons.calendar_month, size: 64, color: Colors.white24),
                      const SizedBox(height: 14),
                      const Text('No hay eventos programados en el calendario.', style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _controller.selectedClanEvents.length,
                itemBuilder: (context, index) {
                  final e = _controller.selectedClanEvents[index];
                  return Card(
                    color: const Color(0xff1B1625),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.event, color: accent),
                      ),
                      title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(e.description),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${e.eventDate.day}/${e.eventDate.month} a las ${e.eventDate.hour}:${e.eventDate.minute.toString().padLeft(2, '0')}', style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
                          Text(e.type, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showCreateEventDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateEventDialog(clanId: widget.clanId),
    );
  }

  // ==========================
  // ACTIVITY TAB
  // ==========================

  Widget _buildActivityTab(ClanModel clan, Color accent) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _controller.selectedClanHistory.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history_toggle_off_outlined, size: 64, color: Colors.white24),
                  const SizedBox(height: 14),
                  const Text('No hay actividad registrada.', style: TextStyle(color: Colors.white54)),
                ],
              ),
            )
          : ListView.builder(
              controller: _historyScrollController,
              padding: const EdgeInsets.all(24),
              itemCount: _controller.selectedClanHistory.length,
              itemBuilder: (context, index) {
                final h = _controller.selectedClanHistory[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: h.avatarUrl != null ? NetworkImage(h.avatarUrl!) : null,
                        radius: 14,
                        child: h.avatarUrl == null ? const Icon(Icons.person, size: 14) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                            children: [
                              TextSpan(text: h.username, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              const TextSpan(text: ' '),
                              TextSpan(text: h.description),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        '${h.createdAt.hour}:${h.createdAt.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ==========================
  // ACCIONES COMPLEMENTARIAS
  // ==========================

  void _pickLogo() async {
    final bytes = await ImagePickerService.pickImage();
    if (bytes != null) {
      await _controller.uploadClanLogo(bytes);
    }
  }

  void _pickBanner() async {
    final bytes = await ImagePickerService.pickImage();
    if (bytes != null) {
      await _controller.uploadClanBanner(bytes);
    }
  }

  void _joinVoiceChannel() async {
    final voiceChannel = await ClanService.instance.getClanVoiceChannel(widget.clanId);
    if (voiceChannel != null) {
      await VoiceChannelService().joinChannel(voiceChannel.id);
      await VoiceRoomController.instance.connect(voiceChannel.roomName, channel: voiceChannel);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo encontrar el canal de voz del clan.')),
      );
    }
  }

  void _showEditClanDialog() {
    showDialog(
      context: context,
      builder: (context) => _EditClanDialog(clan: _controller.selectedClan!),
    );
  }
}

// ==========================
// DESLIZANTE DE CHAT DE CLAN
// ==========================

class _ClanChatSidePanel extends StatefulWidget {
  const _ClanChatSidePanel({
    required this.clanId,
    required this.clanName,
    required this.accentColor,
    required this.onClose,
  });

  final String clanId;
  final String clanName;
  final Color accentColor;
  final VoidCallback onClose;

  @override
  State<_ClanChatSidePanel> createState() => _ClanChatSidePanelState();
}

class _ClanChatSidePanelState extends State<_ClanChatSidePanel> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _chatChannel;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupChatRealtime();
  }

  @override
  void dispose() {
    _chatChannel?.unsubscribe();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final rows = await _supabase
          .from('clan_messages')
          .select('*, profiles(username, avatar_url)')
          .eq('clan_id', widget.clanId)
          .order('created_at', ascending: true)
          .limit(100);

      setState(() {
        _messages = List<Map<String, dynamic>>.from(rows);
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }

  void _setupChatRealtime() {
    _chatChannel = _supabase
        .channel('clan_chat_${widget.clanId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'clan_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'clan_id',
            value: widget.clanId,
          ),
          callback: (payload) async {
            final senderId = payload.newRecord['sender_id'].toString();
            final profile = await _supabase.from('profiles').select('username, avatar_url').eq('id', senderId).single();
            
            final fullMsg = {
              ...payload.newRecord,
              'profiles': profile,
            };

            if (mounted) {
              setState(() {
                _messages.add(fullMsg);
              });
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('clan_messages').insert({
        'clan_id': widget.clanId,
        'sender_id': userId,
        'content': text,
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      decoration: const BoxDecoration(
        color: Color(0xff100D1A),
        border: Border(left: BorderSide(color: Color(0xff2d2543))),
      ),
      child: Column(
        children: [
          // Header del Chat
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(color: Color(0xff161324), border: Border(bottom: BorderSide(color: Color(0xff2d2543)))),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_rounded, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Chat del Clan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                      Text(widget.clanName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white60), onPressed: widget.onClose),
              ],
            ),
          ),

          // Lista de Mensajes
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final sender = m['profiles'] as Map<String, dynamic>? ?? {};
                final senderName = sender['username']?.toString() ?? 'Usuario';
                final avatar = sender['avatar_url']?.toString() ?? '';
                final isMe = m['sender_id'] == _supabase.auth.currentUser?.id;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? widget.accentColor.withOpacity(0.15) : const Color(0xff1B1625),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Text(senderName, style: TextStyle(color: widget.accentColor, fontWeight: FontWeight.bold, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(m['content'].toString(), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Campo de Entrada
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xff141120),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Envía un mensaje al chat...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xff1B1625),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send_rounded, color: widget.accentColor),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================
// DIÁLOGO CREAR EVENTO
// ==========================

class _CreateEventDialog extends StatefulWidget {
  const _CreateEventDialog({required this.clanId});
  final String clanId;

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  String _type = 'Entrenamiento';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xff1B1625),
      title: const Text('Programar Gremio Evento'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre del Evento'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _type,
                    items: ['Entrenamiento', 'Reunión', 'Torneo', 'Evento', 'Stream']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) => setState(() => _type = val!),
                    decoration: const InputDecoration(labelText: 'Tipo de Evento'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Fecha y Hora'),
              subtitle: Text('${_date.day}/${_date.month}/${_date.year} ${_date.hour}:${_date.minute.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.date_range),
              onTap: _pickDateTime,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff6438FF)),
          child: const Text('Programar'),
        ),
      ],
    );
  }

  void _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return;

    if (!mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (t == null) return;

    setState(() {
      _date = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ClanController.instance.createClanEvent(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      eventDate: _date,
      type: _type,
    );
    if (mounted) Navigator.pop(context);
  }
}

// ==========================
// DIÁLOGO EDITAR CLAN
// ==========================

class _EditClanDialog extends StatefulWidget {
  const _EditClanDialog({required this.clan});
  final ClanModel clan;

  @override
  State<_EditClanDialog> createState() => _EditClanDialogState();
}

class _EditClanDialogState extends State<_EditClanDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _tagCtrl;
  late TextEditingController _descCtrl;

  late String _region;
  late String _language;
  late String _visibility;
  late String _clanType;
  late String _accentColor;

  final List<String> _colors = ['#6438FF', '#FF4655', '#1ED760', '#FFB800', '#00A3FF', '#E31B23'];

  int get _daysSinceCreation {
    final now = DateTime.now();
    return now.difference(widget.clan.createdAt).inDays;
  }

  bool get _canDelete {
    return _daysSinceCreation >= 30;
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.clan.name);
    _tagCtrl = TextEditingController(text: widget.clan.tag);
    _descCtrl = TextEditingController(text: widget.clan.description);
    _region = widget.clan.region;
    _language = widget.clan.language;
    _visibility = widget.clan.visibility;
    _clanType = widget.clan.clanType;
    _accentColor = widget.clan.accentColor;
  }

  void _deleteClan() async {
    final controller = ClanController.instance;
    final clan = widget.clan;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || clan.ownerId != user.id) return;

    final nameController = TextEditingController();
    final isConfirmEnabled = ValueNotifier<bool>(false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff1B1625),
          title: Text('¿Eliminar el gremio ${clan.name}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estás a punto de eliminar permanentemente el gremio "${clan.name}". Esta acción no se puede deshacer.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Text(
                'Escribe "${clan.name}" para confirmar:',
                style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: isConfirmEnabled,
                builder: (context, enabled, _) {
                  return Column(
                    children: [
                      TextField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Nombre del clan',
                          hintStyle: TextStyle(color: Colors.white30),
                        ),
                        onChanged: (val) {
                          isConfirmEnabled.value = val.trim() == clan.name.trim();
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: isConfirmEnabled,
              builder: (context, enabled, _) {
                return ElevatedButton(
                  onPressed: enabled
                      ? () => Navigator.pop(context, true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffE31B23),
                  ),
                  child: const Text('ELIMINAR DEFINITIVAMENTE'),
                );
              },
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await controller.deleteClan(clan.id);
        if (mounted) {
          // Cerrar el diálogo de edición
          Navigator.pop(context);
          // Cerrar la página de detalles del clan
          Navigator.pop(context);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Clan eliminado correctamente.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar el clan: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isOwner = widget.clan.ownerId == user?.id;

    return AlertDialog(
      backgroundColor: const Color(0xff1B1625),
      title: const Text('Editar Gremio'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del Clan'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _tagCtrl,
                decoration: const InputDecoration(labelText: 'TAG (Etiqueta)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 2,
              ),
              DropdownButtonFormField<String>(
                value: _region,
                items: ['Global', 'LATAM', 'Norteamérica', 'Europa', 'Asia'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) => setState(() => _region = val!),
                decoration: const InputDecoration(labelText: 'Región'),
              ),
              DropdownButtonFormField<String>(
                value: _language,
                items: ['Español', 'English', 'Português', '日本語', 'Français'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (val) => setState(() => _language = val!),
                decoration: const InputDecoration(labelText: 'Idioma'),
              ),
              DropdownButtonFormField<String>(
                value: _visibility,
                items: ['public', 'private', 'invite_only'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (val) => setState(() => _visibility = val!),
                decoration: const InputDecoration(labelText: 'Privacidad'),
              ),
              DropdownButtonFormField<String>(
                value: _clanType,
                items: ['casual', 'competitive'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _clanType = val!),
                decoration: const InputDecoration(labelText: 'Estilo de Juego'),
              ),
              const SizedBox(height: 14),
              Row(
                children: _colors.map((color) {
                  final isSelected = _accentColor == color;
                  final colorVal = Color(int.tryParse(color.replaceAll('#', '0xff')) ?? 0xff6438FF);
                  return GestureDetector(
                    onTap: () => setState(() => _accentColor = color),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: colorVal,
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (isOwner) ...[
                const Divider(color: Colors.white12, height: 32),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ZONA DE PELIGRO',
                    style: TextStyle(color: Color(0xffFF4655), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Eliminar clan',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _canDelete
                                ? 'Esta acción eliminará permanentemente el clan y no se puede deshacer.'
                                : 'Podrás eliminar el clan en ${30 - _daysSinceCreation} días (Disponible el ${widget.clan.createdAt.add(const Duration(days: 30)).day}/${widget.clan.createdAt.add(const Duration(days: 30)).month}/${widget.clan.createdAt.add(const Duration(days: 30)).year}).',
                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _canDelete ? _deleteClan : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffFF4655),
                        disabledBackgroundColor: Colors.white10,
                      ),
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff6438FF)),
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ClanController.instance.updateClanInfo(
      name: _nameCtrl.text.trim(),
      tag: _tagCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      region: _region,
      language: _language,
      visibility: _visibility,
      clanType: _clanType,
      accentColor: _accentColor,
    );
    if (mounted) Navigator.pop(context);
  }
}

// Delegate helper para SliverPersistentHeader
class _SliverTabDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xff120F1A),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabDelegate oldDelegate) {
    return false;
  }
}


