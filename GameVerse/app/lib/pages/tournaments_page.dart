import 'package:flutter/material.dart';
import '../controllers/tournament_controller.dart';
import '../widgets/tournaments/tournament_card.dart';
import '../pages/create_tournament_page.dart';
import '../services/app_media_service.dart';

class TournamentsPage extends StatefulWidget {
  const TournamentsPage({super.key});

  @override
  State<TournamentsPage> createState() => _TournamentsPageState();
}

class _TournamentsPageState extends State<TournamentsPage> {
  final TournamentController _controller = TournamentController.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String? _heroImageUrl;

  final List<Map<String, String>> _categories = [
    {'id': 'all', 'label': 'Todos'},
    {'id': 'official', 'label': 'Oficiales 🏆'},
    {'id': 'community', 'label': 'De Comunidad'},
    {'id': 'live', 'label': 'En Vivo 🔴'},
    {'id': 'upcoming', 'label': 'Próximos'},
    {'id': 'finished', 'label': 'Finalizados'},
  ];

  final List<Map<String, String>> _featuredGames = [
    {
      'name': 'League of Legends',
      'image':
          'https://brand.riotgames.com/d/6stX7KV6CH03/logo-assets#/logos/lol-logo',
    },
    {
      'name': 'Valorant',
      'image':
          'https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=3540&auto=format&fit=crop',
    },
    {
      'name': 'Fortnite',
      'image':
          'https://images.unsplash.com/photo-1589241062272-c0a000072dfa?q=80&w=3000&auto=format&fit=crop',
    },
    {
      'name': 'Counter-Strike 2',
      'image':
          'https://images.unsplash.com/photo-1552820728-8b83bb6b773f?q=80&w=3000&auto=format&fit=crop',
    },
    {
      'name': 'Minecraft',
      'image':
          'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?q=80&w=3000&auto=format&fit=crop',
    },
  ];

  @override
  void initState() {
    super.initState();
    _controller.loadTournaments(reset: true);
    _controller.loadCommunityStats();
    _loadHeroImage();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadHeroImage() async {
    final url = await AppMediaService.instance.publicUrlFor(
      'tournaments_hero_background',
    );
    if (mounted) setState(() => _heroImageUrl = url);
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
      _controller.loadTournaments(reset: false);
    }
  }

  void _onSearchChanged(String val) {
    _controller.setFilter(query: val);
  }

  Widget _buildTournamentHero() {
    final stats = _controller.communityStats;
    final tournaments = stats['tournaments'] ?? 0;
    final participants = stats['participants'] ?? 0;
    final live = stats['live'] ?? 0;
    final upcoming = stats['upcoming'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xff34106a), Color(0xff10071e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3F000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (_heroImageUrl != null)
            Positioned.fill(
              child: Image.network(
                _heroImageUrl!,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xff10031f).withOpacity(0.95),
                    const Color(0xff16052b).withOpacity(0.54),
                    const Color(0xff0b0614).withOpacity(0.08),
                  ],
                  stops: const [0, 0.48, 1],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xff9A6DFF).withOpacity(0.35),
                    ),
                  ),
                  child: const Text(
                    'COMPETENCIA DE ÉLITE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Torneos Arena',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Únete a torneos oficiales de la comunidad o crea tu propia\narena competitiva con amigos. ¡Compite por la gloria!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _buildHeroStat(
                      Icons.emoji_events_rounded,
                      '$tournaments Torneos',
                      'Registrados',
                    ),
                    _buildHeroStat(
                      Icons.people_rounded,
                      '$participants Jugadores',
                      'Inscritos',
                    ),
                    _buildHeroStat(
                      Icons.sensors_rounded,
                      '$live En vivo',
                      'Ahora',
                    ),
                    _buildHeroStat(
                      Icons.calendar_month_rounded,
                      '$upcoming Próximos',
                      'Por iniciar',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(IconData icon, String value, String label) {
    return Container(
      width: 128,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xff180d31).withOpacity(0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: const Color(0xffA977FF)),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white60, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff130F1A),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                _controller.loadTournaments(reset: true),
                _controller.loadCommunityStats(),
              ]);
            },
            color: const Color(0xff7B4DFF),
            backgroundColor: const Color(0xff1A1625),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Top Banner
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: AspectRatio(
                      // Misma proporción visual que el hero de Clanes.
                      // El arte se contiene completo, sin recortar el trofeo
                      // ni su tipografía.
                      aspectRatio: 3.2,
                      child: _buildTournamentHero(),
                    ),
                  ),
                ),

                /*
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Color(0xff6438FF), Color(0xff1f1338)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x3F000000),
                              blurRadius: 16,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            if (_heroImageUrl != null)
                              Positioned.fill(
                                child: Image.network(
                                  _heroImageUrl!,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.center,
                                  errorBuilder: (_, _, _) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            // Mantiene el texto claro y deja el trofeo visible a
                            // la derecha de la tarjeta.
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xff15052d).withOpacity(0.94),
                                      const Color(0xff190635).withOpacity(0.52),
                                      const Color(0xff0b0614).withOpacity(0.12),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: -30,
                              bottom: -30,
                              child: Icon(
                                Icons.emoji_events_rounded,
                                size: 260,
                                color: Colors.white.withOpacity(0.05),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 24,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'COMPETENCIA DE ÉLITE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Torneos Arena',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Únete a torneos oficiales de la comunidad o crea tu propia\narena competitiva con amigos. ¡Compite por la gloria!',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ),
                */

                // Search & Filter Header Row
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        // Search bar
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xff1A1625),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xff2d2543),
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: Colors.white30,
                                  size: 20,
                                ),
                                hintText: 'Buscar torneo o juego...',
                                hintStyle: TextStyle(
                                  color: Colors.white24,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Create tournament button
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreateTournamentPage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff6438FF),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 8,
                            shadowColor: const Color(
                              0xff6438FF,
                            ).withOpacity(0.4),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text(
                            'Crear Torneo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Featured Games Carousel Title
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Juegos Destacados',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                // Featured Games Carousel Horizontal List
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _featuredGames.length,
                      itemBuilder: (context, index) {
                        final game = _featuredGames[index];
                        final isSelected =
                            _controller.activeQuery == game['name'];

                        return GestureDetector(
                          onTap: () {
                            if (isSelected) {
                              _controller.setFilter(query: '');
                              _searchController.clear();
                            } else {
                              _controller.setFilter(query: game['name']);
                              _searchController.text = game['name']!;
                            }
                          },
                          child: Container(
                            width: 150,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xff7B4DFF)
                                    : const Color(0xff2d2543),
                                width: isSelected ? 1.5 : 1,
                              ),
                              gradient: LinearGradient(
                                colors: isSelected
                                    ? [
                                        const Color(0xff39226B),
                                        const Color(0xff1f1338),
                                      ]
                                    : [
                                        const Color(0xff1C1829),
                                        const Color(0xff120E1C),
                                      ],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                game['name']!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Categories Row (Rediseñado completamente estilo Dashboard/Riot Client)
                SliverToBoxAdapter(
                  child: Container(
                    height: 54,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff1B1728),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xff2d2543),
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: _categories.map((cat) {
                            final isSelected =
                                _controller.activeCategory == cat['id'];

                            // Mapear icono de Material según la pestaña
                            IconData iconData;
                            Color? iconColor;
                            switch (cat['id']) {
                              case 'all':
                                iconData = Icons.check_circle_outline_rounded;
                                break;
                              case 'official':
                                iconData = Icons.emoji_events_rounded;
                                break;
                              case 'community':
                                iconData = Icons.people_alt_rounded;
                                break;
                              case 'live':
                                iconData = Icons.circle;
                                iconColor = const Color(
                                  0xffD64A68,
                                ); // Rojo vibrante para en vivo
                                break;
                              case 'upcoming':
                                iconData = Icons.calendar_month_rounded;
                                break;
                              case 'finished':
                                iconData = Icons.check_circle_rounded;
                                break;
                              default:
                                iconData = Icons.grid_view_rounded;
                            }

                            return _CategoryTab(
                              label: cat['label']!,
                              icon: iconData,
                              iconColor: iconColor,
                              isSelected: isSelected,
                              onTap: () {
                                _controller.setFilter(category: cat['id']);
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),

                // Tournaments Main List Feed
                if (_controller.isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xff7B4DFF),
                      ),
                    ),
                  )
                else if (_controller.tournaments.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.emoji_events_outlined,
                            color: Colors.white24,
                            size: 64,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No se encontraron torneos',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Builder(
                    builder: (context) {
                      final width = MediaQuery.of(context).size.width;
                      int crossAxisCount = 1;
                      double spacing = 16.0;
                      if (width >= 1200) {
                        crossAxisCount = 3;
                      } else if (width >= 768) {
                        crossAxisCount = 2;
                      } else {
                        crossAxisCount = 1;
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.all(24),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: spacing,
                            mainAxisSpacing: spacing,
                            childAspectRatio:
                                1.38, // Relación de aspecto horizontal perfecta (400 px ancho / 290 px alto)
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (index < _controller.tournaments.length) {
                                return TournamentCard(
                                  tournament: _controller.tournaments[index],
                                );
                              }
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xff7B4DFF),
                                  ),
                                ),
                              );
                            },
                            childCount:
                                _controller.tournaments.length +
                                (_controller.hasMore ? 1 : 0),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryTab extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color? iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTab({
    required this.label,
    required this.icon,
    this.iconColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<_CategoryTab> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const activeBgGradient = LinearGradient(
      colors: [Color(0xff8B5CFF), Color(0xff6438FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: widget.isSelected ? activeBgGradient : null,
            color: widget.isSelected
                ? null
                : (_isHovered ? Colors.white10 : Colors.transparent),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xff6438FF).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
            // Riot Client style bottom purple line
            border: Border(
              bottom: BorderSide(
                color: widget.isSelected
                    ? const Color(0xff7B4DFF)
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: widget.isSelected
                    ? Colors.white
                    : (widget.iconColor ??
                          (widget.isSelected ? Colors.white : Colors.white38)),
                size: widget.icon == Icons.circle ? 8 : 16,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isSelected ? Colors.white : Colors.white60,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
