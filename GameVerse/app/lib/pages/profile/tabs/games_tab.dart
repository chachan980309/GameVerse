import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/game_search_result.dart';
import '../../../models/user_game.dart';
import '../../../services/game_search_service.dart';
import '../../../services/user_games_service.dart';
import '../../../utils/game_catalog.dart';

class GamesTab extends StatefulWidget {
  const GamesTab({super.key});

  @override
  State<GamesTab> createState() => _GamesTabState();
}

class _GamesTabState extends State<GamesTab> {
  final _service = UserGamesService();
  late Future<List<UserGame>> _games = _service.getMyGames();

  void _reload() {
    setState(() {
      _games = _service.getMyGames();
    });
  }

  Future<void> _addGame() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => const _GameDialog(),
    );
    if (added == true) _reload();
  }

  Future<void> _removeGame(UserGame game) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF211E2E),
        title: const Text(
          '¿Eliminar juego?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '${game.gameName} se quitará de tu perfil.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Color(0xFFFF6B81)),
            ),
          ),
        ],
      ),
    );
    if (remove != true) return;
    try {
      await _service.removeGame(game.id);
      if (mounted) {
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${game.gameName} fue eliminado.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar el juego: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<UserGame>>(
    future: _games,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF6D35F5)),
        );
      }
      if (snapshot.hasError) {
        return Center(
          child: Text(
            'No se pudieron cargar tus juegos: ${snapshot.error}',
            style: const TextStyle(color: Colors.white70),
          ),
        );
      }
      final games = snapshot.data ?? [];
      return ListView(
        padding: const EdgeInsets.all(28),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mis juegos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addGame,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar juego'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6D35F5),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (games.isEmpty) _emptyState() else ...games.map(_gameCard),
        ],
      );
    },
  );

  Widget _emptyState() => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: const Color(0xFF211E2E),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Column(
      children: [
        Icon(Icons.sports_esports_outlined, color: Color(0xFF9A78FF), size: 42),
        SizedBox(height: 12),
        Text(
          'Aún no has añadido juegos.',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    ),
  );

  Widget _gameCard(UserGame game) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF211E2E),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF39324F)),
    ),
    child: Row(
      children: [
        _gameLogo(game, 48),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      game.gameName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (game.isFavorite)
                    const Padding(
                      padding: EdgeInsets.only(left: 7),
                      child: Icon(
                        Icons.star_rounded,
                        size: 19,
                        color: Color(0xFFFFC14D),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              if (game.gamerTag.isNotEmpty)
                Text(
                  'Usuario: ${game.gamerTag}',
                  style: const TextStyle(
                    color: Color(0xFFBDAAFF),
                    fontSize: 12,
                  ),
                ),
              Text(
                [
                  if (game.platform.isNotEmpty) game.platform,
                  if (game.rank != null && game.rank!.isNotEmpty) game.rank!,
                  '${game.hoursPlayed} horas',
                ].join(' · '),
                style: const TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _removeGame(game),
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54),
          tooltip: 'Eliminar juego',
        ),
      ],
    ),
  );

  Widget _gameLogo(UserGame game, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFF30274B),
      borderRadius: BorderRadius.circular(12),
    ),
    clipBehavior: Clip.antiAlias,
    child: _networkLogo(game.imageUrl, game.gameName),
  );

  Widget _networkLogo(String imageUrl, String gameName) {
    if (!imageUrl.startsWith('http')) return _logoBadge(gameName);
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _logoBadge(gameName),
    );
  }

  Widget _logoBadge(String name) => Container(
    color: const Color(0xFF30274B),
    alignment: Alignment.center,
    child: Text(
      GameCatalog.badgeFor(name),
      style: const TextStyle(
        color: Color(0xFFBDAAFF),
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
    ),
  );
}

class _GameDialog extends StatefulWidget {
  const _GameDialog();

  @override
  State<_GameDialog> createState() => _GameDialogState();
}

class _GameDialogState extends State<_GameDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _platform = TextEditingController(text: 'PC');
  final _rank = TextEditingController();
  final _gamerTag = TextEditingController();
  final _hours = TextEditingController(text: '0');
  final _searchService = GameSearchService();
  Timer? _debounce;
  bool _favorite = false;
  bool _saving = false;
  bool _searching = false;
  List<GameSearchResult> _suggestions = [];
  GameSearchResult? _selectedGame;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    final query = _name.text.trim();
    if (_selectedGame?.name != query) _selectedGame = null;
    _debounce?.cancel();
    _searchError = null;
    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _searching = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _suggestions = [];
    });
    _debounce = Timer(const Duration(milliseconds: 150), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    setState(() => _searching = true);
    try {
      final games = await _searchService.search(query);
      if (!mounted || _name.text.trim() != query) return;
      setState(() {
        _suggestions = games;
        if (games.isEmpty) {
          _searchError = 'No encontramos juegos con "$query".';
        }
      });
    } catch (error) {
      if (mounted && _name.text.trim() == query) {
        setState(() {
          _suggestions = [];
          _searchError = 'No se pudo buscar juegos: $error';
        });
      }
    } finally {
      if (mounted && _name.text.trim() == query) {
        setState(() => _searching = false);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.removeListener(_onNameChanged);
    _name.dispose();
    _platform.dispose();
    _rank.dispose();
    _gamerTag.dispose();
    _hours.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final game = _selectedGame;
    if (game == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un juego de la lista de resultados.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await UserGamesService().addGame(
        game: game,
        platform: _platform.text.trim(),
        rank: _rank.text.trim(),
        gamerTag: _gamerTag.text.trim(),
        hoursPlayed: int.parse(_hours.text),
        isFavorite: _favorite,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el juego: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xFF211E2E),
    title: const Text('Agregar juego', style: TextStyle(color: Colors.white)),
    content: Form(
      key: _formKey,
      child: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _gameSearchField(),
            if (_searching)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(color: Color(0xFF8B5CF6)),
              ),
            if (_suggestions.isNotEmpty) _suggestionList(),
            if (_searchError != null) _searchErrorMessage(),
            if (_selectedGame != null) _selectedGameNotice(),
            _field(_platform, 'Plataforma'),
            _field(
              _gamerTag,
              'Usuario dentro del juego',
              hint: 'Ej.: MiEpicID o Nombre#1234',
              required: true,
            ),
            _field(_rank, 'Rango o nivel (opcional)'),
            _field(_hours, 'Horas jugadas', number: true, required: true),
            SwitchListTile(
              value: _favorite,
              onChanged: (value) => setState(() => _favorite = value),
              activeThumbColor: const Color(0xFF8B5CF6),
              title: const Text(
                'Juego favorito',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      ElevatedButton(
        onPressed: _saving || _selectedGame == null ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6D35F5),
          foregroundColor: Colors.white,
        ),
        child: Text(_saving ? 'Guardando...' : 'Guardar'),
      ),
    ],
  );

  Widget _suggestionList() => Container(
    constraints: const BoxConstraints(maxHeight: 190),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF191724),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF39324F)),
    ),
    child: ListView.separated(
      shrinkWrap: true,
      itemCount: _suggestions.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFF39324F)),
      itemBuilder: (context, index) {
        final game = _suggestions[index];
        return ListTile(
          dense: true,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 34,
              height: 44,
              child: _suggestionLogo(game),
            ),
          ),
          title: Text(game.name, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            game.platforms.isEmpty
                ? 'Plataforma no especificada'
                : game.platforms.take(3).join(' · '),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            setState(() {
              _selectedGame = game;
              _name.text = game.name;
              _platform.text = game.suggestedPlatform;
              _suggestions = [];
            });
            _debounce?.cancel();
          },
        );
      },
    ),
  );

  Widget _selectedGameNotice() => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF193B32),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF37D996)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF37D996),
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${_selectedGame!.name} seleccionado',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _searchErrorMessage() => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFF42212A),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFFF6B81)),
    ),
    child: Text(
      _searchError!,
      style: const TextStyle(color: Colors.white70, fontSize: 12),
    ),
  );

  Widget _gameSearchField() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _name,
      style: const TextStyle(color: Colors.white),
      onFieldSubmitted: (value) {
        _debounce?.cancel();
        _search(value.trim());
      },
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Completa este campo.';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: 'Busca un juego y toca un resultado',
        hintText: 'Ej.: Fortnite, Minecraft o Valorant',
        hintStyle: const TextStyle(color: Colors.white38),
        labelStyle: const TextStyle(color: Color(0xFFBDAAFF)),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF39324F)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF8B5CF6)),
        ),
        suffixIcon: IconButton(
          tooltip: 'Buscar juego',
          onPressed: () {
            _debounce?.cancel();
            _search(_name.text.trim());
          },
          icon: const Icon(Icons.search_rounded, color: Color(0xFFBDAAFF)),
        ),
      ),
    ),
  );

  Widget _suggestionLogo(GameSearchResult game) {
    final url = game.coverUrl;
    if (url == null || !url.startsWith('http')) {
      return _suggestionBadge(game.name);
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _suggestionBadge(game.name),
    );
  }

  Widget _suggestionBadge(String name) => Container(
    color: const Color(0xFF30274B),
    alignment: Alignment.center,
    child: Text(
      GameCatalog.badgeFor(name),
      style: const TextStyle(
        color: Color(0xFFBDAAFF),
        fontWeight: FontWeight.w800,
        fontSize: 10,
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    bool number = false,
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return 'Completa este campo.';
        }
        if (number && int.tryParse(value ?? '') == null) {
          return 'Escribe un número válido.';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        labelStyle: const TextStyle(color: Color(0xFFBDAAFF)),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF39324F)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF8B5CF6)),
        ),
      ),
    ),
  );
}
