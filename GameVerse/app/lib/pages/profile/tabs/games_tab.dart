import 'package:flutter/material.dart';

import '../../../models/user_game.dart';
import '../../../services/user_games_service.dart';

class GamesTab extends StatefulWidget {
  const GamesTab({super.key});

  @override
  State<GamesTab> createState() => _GamesTabState();
}

class _GamesTabState extends State<GamesTab> {
  final _service = UserGamesService();
  late Future<List<UserGame>> _games = _service.getMyGames();

  void _reload() => setState(() => _games = _service.getMyGames());

  Future<void> _addGame() async {
    final added = await showDialog<bool>(context: context, builder: (_) => const _GameDialog());
    if (added == true) _reload();
  }

  Future<void> _removeGame(UserGame game) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF211E2E),
        title: const Text('¿Eliminar juego?', style: TextStyle(color: Colors.white)),
        content: Text('${game.gameName} se quitará de tu perfil.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Color(0xFFFF6B81)))),
        ],
      ),
    );
    if (remove != true) return;
    await _service.removeGame(game.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<UserGame>>(
        future: _games,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF6D35F5)));
          }
          if (snapshot.hasError) {
            return Center(child: Text('No se pudieron cargar tus juegos: ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
          }
          final games = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(28),
            children: [
              Row(children: [
                const Expanded(child: Text('Mis juegos', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
                ElevatedButton.icon(
                  onPressed: _addGame,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar juego'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D35F5), foregroundColor: Colors.white),
                ),
              ]),
              const SizedBox(height: 20),
              if (games.isEmpty)
                _emptyState()
              else
                ...games.map(_gameCard),
            ],
          );
        },
      );

  Widget _emptyState() => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: const Color(0xFF211E2E), borderRadius: BorderRadius.circular(14)),
        child: const Column(children: [
          Icon(Icons.sports_esports_outlined, color: Color(0xFF9A78FF), size: 42),
          SizedBox(height: 12),
          Text('Aún no has añadido juegos.', style: TextStyle(color: Colors.white70)),
        ]),
      );

  Widget _gameCard(UserGame game) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF211E2E), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF39324F))),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: const Color(0xFF30274B), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.sports_esports_rounded, color: Color(0xFFAF8CFF)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(game.gameName, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700))),
              if (game.isFavorite) const Padding(padding: EdgeInsets.only(left: 7), child: Icon(Icons.star_rounded, size: 19, color: Color(0xFFFFC14D))),
            ]),
            const SizedBox(height: 4),
            Text([if (game.platform.isNotEmpty) game.platform, if (game.rank != null && game.rank!.isNotEmpty) game.rank!, '${game.hoursPlayed} horas'].join(' · '), style: const TextStyle(color: Colors.white54)),
          ])),
          IconButton(onPressed: () => _removeGame(game), icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54), tooltip: 'Eliminar juego'),
        ]),
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
  final _hours = TextEditingController(text: '0');
  bool _favorite = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose(); _platform.dispose(); _rank.dispose(); _hours.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await UserGamesService().addGame(
        gameName: _name.text.trim(), platform: _platform.text.trim(),
        rank: _rank.text.trim(), hoursPlayed: int.parse(_hours.text), isFavorite: _favorite,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar el juego: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: const Color(0xFF211E2E),
        title: const Text('Agregar juego', style: TextStyle(color: Colors.white)),
        content: Form(key: _formKey, child: SizedBox(width: 430, child: Column(mainAxisSize: MainAxisSize.min, children: [
          _field(_name, 'Nombre del juego', required: true),
          _field(_platform, 'Plataforma'),
          _field(_rank, 'Rango o nivel (opcional)'),
          _field(_hours, 'Horas jugadas', number: true, required: true),
          SwitchListTile(value: _favorite, onChanged: (value) => setState(() => _favorite = value), activeThumbColor: const Color(0xFF8B5CF6), title: const Text('Juego favorito', style: TextStyle(color: Colors.white))),
        ]))),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(onPressed: _saving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D35F5), foregroundColor: Colors.white), child: const Text('Guardar')),
        ],
      );

  Widget _field(TextEditingController controller, String label, {bool number = false, bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller, keyboardType: number ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: Colors.white),
          validator: (value) {
            if (required && (value == null || value.trim().isEmpty)) return 'Completa este campo.';
            if (number && int.tryParse(value ?? '') == null) return 'Escribe un número válido.';
            return null;
          },
          decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Color(0xFFBDAAFF)), enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF39324F))), focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6)))),
        ),
      );
}
