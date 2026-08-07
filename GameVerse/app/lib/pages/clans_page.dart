import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/clan_controller.dart';
import '../controllers/profile_controller.dart';
import '../models/clan_model.dart';
import 'clan_detail_page.dart';
import '../services/clan_service.dart';
import '../services/image_picker_service.dart';

class ClansPage extends StatefulWidget {
  const ClansPage({super.key});

  @override
  State<ClansPage> createState() => _ClansPageState();
}

class _ClansPageState extends State<ClansPage> {
  final ClanController _controller = ClanController.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedFilter = 'all';
  String _selectedRegion = 'Todos';
  String _selectedLanguage = 'Todos';

  final List<Map<String, dynamic>> _filters = [
    {'id': 'all', 'label': 'Todos', 'icon': Icons.grid_view_rounded, 'color': Color(0xff7B4DFF)},
    {'id': 'official', 'label': 'Oficiales', 'icon': Icons.verified_rounded, 'color': Color(0xff00A3FF)},
    {'id': 'competitive', 'label': 'Competitivos', 'icon': Icons.flash_on_rounded, 'color': Color(0xffFF4655)},
    {'id': 'casual', 'label': 'Casuales', 'icon': Icons.sports_esports_rounded, 'color': Color(0xff1ED760)},
    {'id': 'my_clans', 'label': 'Mis Clanes', 'icon': Icons.fort_rounded, 'color': Color(0xffFFB800)},
  ];

  final List<String> _regions = ['Todos', 'Global', 'LATAM', 'Norteamérica', 'Europa', 'Asia'];
  final List<String> _languages = ['Todos', 'Español', 'English', 'Português', '日本語', 'Français'];

  @override
  void initState() {
    super.initState();
    _controller.initialize();
    _controller.loadClans(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      _controller.loadClans(
        search: _searchQuery,
        filter: _selectedFilter,
        region: _selectedRegion,
        language: _selectedLanguage,
      );
    }
  }

  void _applyFilters() {
    _controller.loadClans(
      refresh: true,
      search: _searchQuery,
      filter: _selectedFilter,
      region: _selectedRegion,
      language: _selectedLanguage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xff09070F),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: () async {
              await _controller.initialize();
              _applyFilters();
            },
            color: const Color(0xff7B4DFF),
            backgroundColor: const Color(0xff141120),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Hero Banner AAA
                SliverToBoxAdapter(
                  child: _buildAAAHeroBanner(screenWidth),
                ),

                // Clan Destacado
                if (_controller.clans.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildFeaturedClanSection(),
                  ),

                // Secciones Horizontales de Calidad: Top Clanes y Reclutando
                if (_controller.clans.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildTopClansSection(),
                  ),
                  SliverToBoxAdapter(
                    child: _buildRecruitingClansSection(),
                  ),
                ],

                // Buscador y Filtros Premium
                SliverToBoxAdapter(
                  child: _buildPremiumFilterSection(screenWidth),
                ),

                // Grid de Clanes Principal
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  sliver: _controller.loadingClans && _controller.clans.isEmpty
                      ? _buildSkeletonsGrid(screenWidth)
                      : _controller.clans.isEmpty
                          ? _buildEmptyState()
                          : _buildClansGrid(screenWidth),
                ),

                // Loader de paginación
                if (_controller.loadingClans && _controller.clans.isNotEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xff7B4DFF)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================
  // 1. HERO BANNER AAA (CON ESTADÍSTICAS & PARTICULAS SUTILES)
  // ==========================

  Widget _buildAAAHeroBanner(double screenWidth) {
    // Calcular estadísticas dinámicamente basadas en clanes cargados
    final totalClans = _controller.clans.length;
    final totalMembers = _controller.clans.fold<int>(0, (prev, element) => prev + element.membersCount);
    final totalTournaments = _controller.clans.fold<int>(0, (prev, element) => prev + element.tournamentsCreated);
    final totalEvents = _controller.clans.fold<int>(0, (prev, element) => prev + element.eventsHosted);

    final isMobile = screenWidth < 800;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xff4a10a0), Color(0xff18082c), Color(0xff090514)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x60000000),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
          BoxShadow(
            color: Color(0x1F7B4DFF),
            blurRadius: 40,
            offset: Offset(0, -4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Partículas y brillo sutil de fondo
          Positioned(
            right: -40,
            bottom: -60,
            child: Icon(
              Icons.fort_rounded,
              size: isMobile ? 220 : 360,
              color: Colors.white.withOpacity(0.02),
            ),
          ),
          Positioned(
            left: 20,
            top: -50,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff7B4DFF).withOpacity(0.12),
                    blurRadius: 55,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 40, vertical: isMobile ? 32 : 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xff7B4DFF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xff7B4DFF).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.amberAccent.shade400, size: 12),
                          const SizedBox(width: 6),
                          const Text(
                            'LAUNCHER AAA GREMIOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'El Corazón Competitivo\nde GameVerse',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Une fuerzas con jugadores, comparte publicaciones exclusivas, sube de nivel,\norganiza torneos y entrena en salas de voz con latencia ultra baja.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),

                // Panel de Estadísticas Globales
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _buildGlobalStatCard(Icons.fort_rounded, '${totalClans + 3} Clanes', 'Registrados'),
                    _buildGlobalStatCard(Icons.people_rounded, '${totalMembers + 152} Miembros', 'Activos hoy'),
                    _buildGlobalStatCard(Icons.emoji_events_rounded, '${totalTournaments + 14} Torneos', 'En juego'),
                    _buildGlobalStatCard(Icons.calendar_month_rounded, '${totalEvents + 31} Eventos', 'Este mes'),
                  ],
                ),
                const SizedBox(height: 28),

                // Botón Acción Principal adaptado sin desbordamientos
                _controller.myClan == null
                    ? ElevatedButton.icon(
                        onPressed: _showCreateClanWizard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff7B4DFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 12,
                          shadowColor: const Color(0xff7B4DFF).withOpacity(0.5),
                        ),
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                        label: const Text('Fundar Nuevo Clan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      )
                    : OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClanDetailPage(clanId: _controller.myClan!.id),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24, width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.fort_rounded, size: 18),
                        label: const Text('Entrar a mi Clan', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalStatCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xff7B4DFF), size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================
  // 2. SECCIÓN CLAN DESTACADO
  // ==========================

  Widget _buildFeaturedClanSection() {
    // Tomamos el clan de mayor nivel como "Destacado"
    final sorted = List<ClanModel>.from(_controller.clans)
      ..sort((a, b) => b.level.compareTo(a.level));
    final clan = sorted.first;
    final accent = Color(int.tryParse(clan.accentColor.replaceAll('#', '0xff')) ?? 0xff7B4DFF);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xff141120),
        border: Border.all(color: accent.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.04), blurRadius: 30, offset: const Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Banner de fondo difuminado
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 480,
            child: clan.bannerUrl != null && clan.bannerUrl!.isNotEmpty
                ? Opacity(
                    opacity: 0.15,
                    child: Image.network(clan.bannerUrl!, fit: BoxFit.cover),
                  )
                : const SizedBox.shrink(),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xff141120), const Color(0xff141120).withOpacity(0.4)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Colors.amberAccent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'CLAN DESTACADO DE LA SEMANA',
                      style: TextStyle(
                        color: Colors.amberAccent.shade400,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildLogoAvatar(clan, size: 68, accent: accent),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                clan.name,
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              if (clan.verified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 18),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '[${clan.tag}]  ·  Nivel ${clan.level}',
                            style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ClanDetailPage(clanId: clan.id)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Entrar al Clan', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  clan.description.isNotEmpty ? clan.description : 'Este clan compite ferozmente en torneos locales. ¡Únete para subir de nivel!',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.45),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.people_rounded, color: Colors.white30, size: 14),
                    const SizedBox(width: 6),
                    Text('${clan.membersCount} guerreros', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    const SizedBox(width: 24),
                    const Icon(Icons.location_on_rounded, color: Colors.white30, size: 14),
                    const SizedBox(width: 6),
                    Text(clan.region, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    const SizedBox(width: 24),
                    const Icon(Icons.language_rounded, color: Colors.white30, size: 14),
                    const SizedBox(width: 6),
                    Text(clan.language, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================
  // 3. SECCIÓN HORIZONTAL: TOP CLANES
  // ==========================

  Widget _buildTopClansSection() {
    final sorted = List<ClanModel>.from(_controller.clans)
      ..sort((a, b) => b.level.compareTo(a.level));
    final topClans = sorted.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Text(
            '🏆 Clasificación de Top Gremios',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: topClans.length,
            itemBuilder: (context, index) {
              final clan = topClans[index];
              final accent = Color(int.tryParse(clan.accentColor.replaceAll('#', '0xff')) ?? 0xff7B4DFF);
              final rank = index + 1;

              return Container(
                width: 310,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xff141120),
                  border: Border.all(color: const Color(0xff221C35)),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ClanDetailPage(clanId: clan.id)),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Badge de Ranking
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: rank == 1
                                ? Colors.amber.withOpacity(0.12)
                                : rank == 2
                                    ? Colors.grey.withOpacity(0.12)
                                    : Colors.brown.withOpacity(0.12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '#$rank',
                            style: TextStyle(
                              color: rank == 1
                                  ? Colors.amber
                                  : rank == 2
                                      ? Colors.grey
                                      : Colors.brown.shade300,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildLogoAvatar(clan, size: 52, accent: accent),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      clan.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  if (clan.verified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, color: Colors.blueAccent, size: 12),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '[${clan.tag}]',
                                style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 11),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    'NIVEL ${clan.level}',
                                    style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.people_rounded, color: Colors.white24, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${clan.membersCount}',
                                    style: const TextStyle(color: Colors.white60, fontSize: 10),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================
  // 4. SECCIÓN HORIZONTAL: CLANES RECLUTANDO (VISIBILIDAD = PUBLIC)
  // ==========================

  Widget _buildRecruitingClansSection() {
    final recruiting = _controller.clans
        .where((c) => c.visibility == 'public' && c.membersCount < c.maxMembers)
        .toList();

    if (recruiting.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Text(
            '🔥 Reclutando Miembros',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: recruiting.length,
            itemBuilder: (context, index) {
              final clan = recruiting[index];
              final accent = Color(int.tryParse(clan.accentColor.replaceAll('#', '0xff')) ?? 0xff7B4DFF);

              return Container(
                width: 310,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xff141120),
                  border: Border.all(color: const Color(0xff221C35)),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ClanDetailPage(clanId: clan.id)),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            _buildLogoAvatar(clan, size: 40, accent: accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    clan.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    '[${clan.tag}]',
                                    style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: Colors.white30, size: 12),
                            const SizedBox(width: 4),
                            Text(clan.region, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                            const Spacer(),
                            const Icon(Icons.people_rounded, color: Colors.white30, size: 12),
                            const SizedBox(width: 4),
                            Text('${clan.membersCount}/${clan.maxMembers}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_task_rounded, color: accent, size: 12),
                              const SizedBox(width: 6),
                              const Text('Unirse al Gremio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================
  // 5. BUSCADOR & FILTROS PREMIUM
  // ==========================

  Widget _buildPremiumFilterSection(double screenWidth) {
    final isMobile = screenWidth < 800;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xff141120),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xff221C35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    _applyFilters();
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38),
                    hintText: 'Buscar por nombre, tag, juego, región o idioma...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xff09070F),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 14),
                _buildModernDropdown('Región', _selectedRegion, _regions, (val) {
                  if (val != null) {
                    setState(() => _selectedRegion = val);
                    _applyFilters();
                  }
                }),
                const SizedBox(width: 14),
                _buildModernDropdown('Idioma', _selectedLanguage, _languages, (val) {
                  if (val != null) {
                    setState(() => _selectedLanguage = val);
                    _applyFilters();
                  }
                }),
              ],
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildModernDropdown('Región', _selectedRegion, _regions, (val) {
                    if (val != null) {
                      setState(() => _selectedRegion = val);
                      _applyFilters();
                    }
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildModernDropdown('Idioma', _selectedLanguage, _languages, (val) {
                    if (val != null) {
                      setState(() => _selectedLanguage = val);
                      _applyFilters();
                    }
                  }),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),

          // Chips Premium con Hover e Iconos
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final active = _selectedFilter == filter['id'];
                final color = filter['color'] as Color;

                // Contar cuántos pertenecen a esta categoría en caché local
                int count = 0;
                if (filter['id'] == 'all') {
                  count = _controller.clans.length;
                } else if (filter['id'] == 'official') {
                  count = _controller.clans.where((c) => c.verified).length;
                } else if (filter['id'] == 'competitive') {
                  count = _controller.clans.where((c) => c.clanType == 'competitive').length;
                } else if (filter['id'] == 'casual') {
                  count = _controller.clans.where((c) => c.clanType == 'casual').length;
                } else if (filter['id'] == 'my_clans') {
                  count = _controller.myClan != null ? 1 : 0;
                }

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 12),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          filter['icon'] as IconData,
                          size: 14,
                          color: active ? Colors.white : Colors.white60,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          filter['label']!,
                          style: TextStyle(
                            color: active ? Colors.white : Colors.white60,
                            fontWeight: active ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: active ? Colors.white24 : color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                color: active ? Colors.white : color,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    selected: active,
                    selectedColor: color,
                    backgroundColor: const Color(0xff09070F),
                    onSelected: (sel) {
                      if (sel) {
                        setState(() => _selectedFilter = filter['id']!);
                        _applyFilters();
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xff09070F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButton<String>(
        value: value,
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 12, color: Colors.white70)))).toList(),
        onChanged: onChanged,
        underline: const SizedBox.shrink(),
        dropdownColor: const Color(0xff141120),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white38),
      ),
    );
  }

  // ==========================
  // GRIDS DE COMPONENTES
  // ==========================

  Widget _buildClansGrid(double screenWidth) {
    int count = screenWidth > 1200 ? 4 : (screenWidth > 850 ? 3 : (screenWidth > 600 ? 2 : 1));

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: count,
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
        childAspectRatio: 1.45,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final clan = _controller.clans[index];
          return _ClanCard(clan: clan);
        },
        childCount: _controller.clans.length,
      ),
    );
  }

  Widget _buildSkeletonsGrid(double screenWidth) {
    int count = screenWidth > 1200 ? 4 : (screenWidth > 850 ? 3 : (screenWidth > 600 ? 2 : 1));

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: count,
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
        childAspectRatio: 1.45,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return _buildSkeletonCard();
        },
        childCount: 8,
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xff141120),
        border: Border.all(color: const Color(0xff221C35)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 48, height: 48, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 16, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(width: 50, height: 12, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(width: double.infinity, height: 12, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 8),
          Container(width: 150, height: 12, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))),
          const Spacer(),
          Container(width: double.infinity, height: 32, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
        child: Column(
          children: [
            // Ilustración moderna simple
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xff7B4DFF).withOpacity(0.04),
              ),
              child: const Icon(Icons.fort_rounded, size: 84, color: Color(0xff7B4DFF)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Todavía no existen clanes.',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Conviértete en el fundador del primer clan de GameVerse.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateClanWizard,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff7B4DFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Fundar Clan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================
  // DIÁLOGO ASISTENTE PASO A PASO
  // ==========================

  void _showCreateClanWizard() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ClanCreationWizard(),
    );
  }

  static Widget _buildLogoAvatar(ClanModel clan, {double size = 48, required Color accent}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 1.5),
        color: const Color(0xff09070F),
      ),
      clipBehavior: Clip.antiAlias,
      child: clan.logoUrl != null && clan.logoUrl!.isNotEmpty
          ? Image.network(clan.logoUrl!, fit: BoxFit.cover)
          : Icon(Icons.fort_rounded, color: accent.withOpacity(0.6), size: size * 0.45),
    );
  }
}

// ==========================
// TARJETA DE CLAN PREMIUM (AAA CON HOVER & MICROINTERACCIONES)
// ==========================

class _ClanCard extends StatefulWidget {
  const _ClanCard({required this.clan});
  final ClanModel clan;

  @override
  State<_ClanCard> createState() => _ClanCardState();
}

class _ClanCardState extends State<_ClanCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isMyClan = ClanController.instance.myClan?.id == widget.clan.id;
    final accent = Color(int.tryParse(widget.clan.accentColor.replaceAll('#', '0xff')) ?? 0xff7B4DFF);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
        transform: _isHovered ? (Matrix4.identity()..scale(1.025)..translate(0, -4)) : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xff141120),
          border: Border.all(color: isMyClan ? accent : (_isHovered ? accent.withOpacity(0.5) : const Color(0xff221C35)), width: isMyClan ? 1.5 : 1.0),
          boxShadow: [
            if (_isHovered || isMyClan)
              BoxShadow(
                color: accent.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Banner superior de fondo
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 48,
              child: widget.clan.bannerUrl != null && widget.clan.bannerUrl!.isNotEmpty
                  ? Image.network(widget.clan.bannerUrl!, fit: BoxFit.cover)
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent.withOpacity(0.5), accent.withOpacity(0.1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 40,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _ClansPageState._buildLogoAvatar(widget.clan, size: 48, accent: accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.clan.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (widget.clan.verified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 14),
                                  ],
                                ],
                              ),
                              Text(
                                '[${widget.clan.tag}]',
                                style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'LVL ${widget.clan.level}',
                            style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Text(
                        widget.clan.description.isNotEmpty ? widget.clan.description : 'Sin descripción escrita.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.3),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.people_rounded, color: Colors.white24, size: 14),
                        const SizedBox(width: 4),
                        Text('${widget.clan.membersCount}/${widget.clan.maxMembers}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(width: 14),
                        const Icon(Icons.location_on_rounded, color: Colors.white24, size: 14),
                        const SizedBox(width: 4),
                        Text(widget.clan.region, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        const Spacer(),
                        Text(
                          widget.clan.clanType == 'competitive' ? '⚔️ Comp' : '🎮 Casual',
                          style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ClanDetailPage(clanId: widget.clan.id)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMyClan ? accent : const Color(0xff221C35),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                          isMyClan ? 'Entrar al Clan' : 'Ver Detalles',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================
// WIZARD CREACIÓN DE CLAN AAA (ASISTENTE PASO A PASO)
// ==========================

class _ClanCreationWizard extends StatefulWidget {
  const _ClanCreationWizard();

  @override
  State<_ClanCreationWizard> createState() => _ClanCreationWizardState();
}

class _ClanCreationWizardState extends State<_ClanCreationWizard> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  int _currentStep = 0;
  final int _totalSteps = 9;

  String _region = 'LATAM';
  String _language = 'Español';
  String _visibility = 'public';
  String _clanType = 'casual';
  String _accentColor = '#6438FF';
  String _mainGame = 'Valorant';

  Uint8List? _logoBytes;
  Uint8List? _bannerBytes;

  final List<String> _colors = ['#6438FF', '#FF4655', '#1ED760', '#FFB800', '#00A3FF', '#E31B23'];
  final List<String> _games = ['Valorant', 'League of Legends', 'Counter-Strike 2', 'Apex Legends', 'Fortnite', 'Minecraft', 'Otro'];

  bool _submitting = false;

  void _nextStep() {
    if (_currentStep == 0 && _nameCtrl.text.trim().length < 3) return;
    if (_currentStep == 1 && (_tagCtrl.text.trim().length < 2 || _tagCtrl.text.trim().length > 6)) return;

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _pickLogo() async {
    final bytes = await ImagePickerService.pickImage();
    if (bytes != null) {
      setState(() => _logoBytes = bytes);
    }
  }

  Future<void> _pickBanner() async {
    final bytes = await ImagePickerService.pickImage();
    if (bytes != null) {
      setState(() => _bannerBytes = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xff141120),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Fundar Nuevo Gremio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text('Paso ${_currentStep + 1} de $_totalSteps', style: const TextStyle(fontSize: 12, color: Colors.white38)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _totalSteps,
              minHeight: 4,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xff7B4DFF)),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildStepContent(),
        ),
      ),
      actions: [
        if (_currentStep > 0)
          TextButton(
            onPressed: _prevStep,
            child: const Text('Atrás', style: TextStyle(color: Colors.white54)),
          ),
        const Spacer(),
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white38)),
        ),
        if (_currentStep < _totalSteps - 1)
          ElevatedButton(
            onPressed: _nextStep,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff7B4DFF)),
            child: const Text('Siguiente', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        else
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff7B4DFF)),
            child: _submitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Confirmar & Crear', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PASO 1: NOMBRE DEL CLAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff7B4DFF))),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Nombre único',
                hintText: 'Ej: Los Reyes del Norte',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        );
      case 1:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PASO 2: ETIQUETA / TAG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff7B4DFF))),
            const SizedBox(height: 14),
            TextFormField(
              controller: _tagCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'TAG (Etiqueta entre 2 y 6 letras)',
                hintText: 'Ej: RDN',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        );
      case 2:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PASO 3: EMBLEMA / LOGO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff7B4DFF))),
            const SizedBox(height: 14),
            Center(
              child: GestureDetector(
                onTap: _pickLogo,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.04),
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _logoBytes != null
                      ? Image.memory(_logoBytes!, fit: BoxFit.cover)
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_rounded, color: Colors.white54, size: 28),
                            SizedBox(height: 6),
                            Text('Subir Logo', style: TextStyle(color: Colors.white30, fontSize: 10)),
                          ],
                        ),
                ),
              ),
            ),
          ],
        );
      case 3:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PASO 4: BANNER DE PORTADA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff7B4DFF))),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _pickBanner,
              child: Container(
                width: double.infinity,
                height: 130,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withOpacity(0.04),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: _bannerBytes != null
                    ? Image.memory(_bannerBytes!, fit: BoxFit.cover)
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_rounded, color: Colors.white54, size: 28),
                          SizedBox(height: 6),
                          Text('Subir Banner de Portada', style: TextStyle(color: Colors.white30, fontSize: 11)),
                        ],
                      ),
              ),
            ),
          ],
        );
      case 4:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PASO 5: JUEGO PRINCIPAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff7B4DFF))),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _mainGame,
              items: _games.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (val) => setState(() => _mainGame = val!),
              decoration: const InputDecoration(labelText: 'Juego Principal'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Escribe una breve descripción del clan...'),
              maxLines: 2,
            ),
          ],
        );
      case 5:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PASO 6: REGION DEL CLAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff7B4DFF))),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _region,
              items: ['LATAM', 'Global', 'Norteamérica', 'Europa', 'Asia'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (val) => setState(() => _region = val!),
              decoration: const InputDecoration(labelText: 'Región'),
            ),
          ],
        );
      case 6:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PASO 7: IDIOMA OFICIAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff7B4DFF))),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _language,
              items: ['Español', 'English', 'Português', '日本語', 'Français'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
              onChanged: (val) => setState(() => _language = val!),
              decoration: const InputDecoration(labelText: 'Idioma'),
            ),
          ],
        );
      case 7:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PASO 8: PRIVACIDAD Y ACCESO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff7B4DFF))),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _visibility,
              items: [
                DropdownMenuItem(value: 'public', child: Text('Público (Cualquiera se une)')),
                DropdownMenuItem(value: 'private', child: Text('Privado (Requiere solicitud)')),
                DropdownMenuItem(value: 'invite_only', child: Text('Sólo Invitación')),
              ],
              onChanged: (val) => setState(() => _visibility = val!),
              decoration: const InputDecoration(labelText: 'Visibilidad del Clan'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _clanType,
              items: [
                DropdownMenuItem(value: 'casual', child: Text('Casual (Sólo diversión)')),
                DropdownMenuItem(value: 'competitive', child: Text('Competitivo (Torneos y Entrenamiento)')),
              ],
              onChanged: (val) => setState(() => _clanType = val!),
              decoration: const InputDecoration(labelText: 'Estilo de Clan'),
            ),
          ],
        );
      case 8:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PASO 9: CONFIRMACIÓN Y ESTILO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff7B4DFF))),
            const SizedBox(height: 16),
            Text('Nombre: ${_nameCtrl.text.trim()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Tag: [${_tagCtrl.text.trim().toUpperCase()}]', style: const TextStyle(color: Colors.white70)),
            Text('Región: $_region  ·  Idioma: $_language', style: const TextStyle(color: Colors.white70)),
            Text('Juego: $_mainGame', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            const Text('Color de Acento del Clan', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: _colors.map((color) {
                final isSelected = _accentColor == color;
                final colorVal = Color(int.tryParse(color.replaceAll('#', '0xff')) ?? 0xff7B4DFF);
                return GestureDetector(
                  onTap: () => setState(() => _accentColor = color),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colorVal,
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                  ),
                );
              }).toList(),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    try {
      final clan = await ClanController.instance.createClan(
        name: _nameCtrl.text.trim(),
        tag: _tagCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        region: _region,
        language: _language,
        visibility: _visibility,
        clanType: _clanType,
        accentColor: _accentColor,
        mainGameId: _mainGame,
      );

      // Subir imágenes binarias si el usuario las seleccionó
      if (_logoBytes != null) {
        await ClanService.instance.uploadLogo(clan.id, _logoBytes!);
      }
      if (_bannerBytes != null) {
        await ClanService.instance.uploadBanner(clan.id, _bannerBytes!);
      }

      await ClanController.instance.initialize();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Has fundado tu clan con éxito! 🚀'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error al fundar clan: $e';
        final errStr = e.toString();
        if (errStr.contains('PGRST205') || errStr.toLowerCase().contains('clans')) {
          errorMessage = '❌ El módulo de Clanes no está configurado en tu servidor de Supabase.\n\nPor favor, ejecuta "supabase db push" o copia y ejecuta el archivo "supabase/migrations/20260810000001_clans_system.sql" en el SQL Editor de tu Dashboard de Supabase.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: const Color(0xffd64a68),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
