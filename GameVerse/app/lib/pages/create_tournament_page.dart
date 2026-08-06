import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../controllers/profile_controller.dart';
import '../controllers/tournament_controller.dart';
import '../services/game_search_service.dart';
import '../models/game_search_result.dart';

class CreateTournamentPage extends StatefulWidget {
  const CreateTournamentPage({super.key});

  @override
  State<CreateTournamentPage> createState() => _CreateTournamentPageState();
}

class _CreateTournamentPageState extends State<CreateTournamentPage> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TournamentController.instance;
  final _gameSearchService = GameSearchService();

  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _gameController = TextEditingController();
  final _rulesController = TextEditingController();
  final _prizesController = TextEditingController();
  final _passwordController = TextEditingController();

  GameSearchResult? _selectedGame;
  List<GameSearchResult> _gameSuggestions = [];
  bool _searchingGames = false;

  int _maxPlayers = 16;
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);

  String _formatType = 'single_elimination'; // 'double_elimination', 'round_robin'
  String _privacy = 'public'; // 'private'
  String _region = 'LATAM'; // 'NA', 'EU', etc.
  bool _isOfficial = false;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _gameController.dispose();
    _rulesController.dispose();
    _prizesController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _searchGames(String val) async {
    if (val.trim().length < 2) {
      setState(() => _gameSuggestions = []);
      return;
    }
    setState(() => _searchingGames = true);
    try {
      final results = await _gameSearchService.search(val);
      setState(() {
        _gameSuggestions = results;
      });
    } catch (_) {}
    setState(() => _searchingGames = false);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xff7B4DFF),
              onPrimary: Colors.white,
              surface: Color(0xff1A1625),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xff7B4DFF),
              onPrimary: Colors.white,
              surface: Color(0xff1A1625),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _submitting) return;

    if (_selectedGame == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona un juego verificado del catálogo.'), backgroundColor: Color(0xffD64A68)),
      );
      return;
    }

    setState(() => _submitting = true);

    final finalDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    try {
      await _controller.createTournament(
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        gameName: _selectedGame!.name,
        gameImageUrl: _selectedGame!.coverUrl,
        gamePosterUrl: _selectedGame!.posterImage,
        gameHeroUrl: _selectedGame!.heroImage,
        gameBackgroundUrl: _selectedGame!.backgroundImage,
        maxPlayers: _maxPlayers,
        startDate: finalDateTime,
        type: _formatType,
        privacy: _privacy,
        password: _privacy == 'private' ? _passwordController.text.trim() : null,
        region: _region,
        rules: _rulesController.text.trim().isNotEmpty ? _rulesController.text.trim() : null,
        prizes: _prizesController.text.trim().isNotEmpty ? _prizesController.text.trim() : null,
        isOfficial: _isOfficial,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Torneo creado con éxito!'), backgroundColor: Color(0xff50E6A5)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear torneo: $e'), backgroundColor: const Color(0xffD64A68)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<ProfileController>(context);
    final isAdmin = profile.role == 'Admin';

    return Scaffold(
      backgroundColor: const Color(0xff130F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xff1A1625),
        title: const Text('Crear Torneo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _formSectionTitle('Detalles del Torneo'),
              const SizedBox(height: 16),
              
              // Tournament Name
              _textFieldLabel('Nombre del Torneo *'),
              TextFormField(
                controller: _nameController,
                validator: (val) => val == null || val.trim().length < 3 ? 'Mínimo 3 caracteres' : null,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _inputDecoration('Ej: Copa de Invierno Fortnite'),
              ),
              const SizedBox(height: 16),

              // Game Search from integrated catalog
              _textFieldLabel('Selecciona el Juego *'),
              TextFormField(
                controller: _gameController,
                onChanged: _searchGames,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _inputDecoration('Escribe para buscar...'),
              ),
              if (_searchingGames)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Center(child: CircularProgressIndicator(color: Color(0xff7B4DFF))),
                ),
              if (_gameSuggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xff1B1625),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xff2d2543)),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _gameSuggestions.length.clamp(0, 5),
                    itemBuilder: (context, index) {
                      final game = _gameSuggestions[index];
                      return ListTile(
                        leading: game.coverUrl != null
                            ? Image.network(game.coverUrl!, width: 32, height: 32, fit: BoxFit.cover)
                            : const Icon(Icons.sports_esports, color: Colors.white30),
                        title: Text(game.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        onTap: () {
                          setState(() {
                            _selectedGame = game;
                            _gameController.text = game.name;
                            _gameSuggestions = [];
                          });
                        },
                      );
                    },
                  ),
                ),
              if (_selectedGame != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xff50E6A5), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Juego verificado: ${_selectedGame!.name}',
                        style: const TextStyle(color: Color(0xff50E6A5), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Description
              _textFieldLabel('Descripción del Torneo *'),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _inputDecoration('Detalla las pautas principales del torneo...'),
              ),
              const SizedBox(height: 24),

              _formSectionTitle('Formato & Configuración'),
              const SizedBox(height: 16),

              // Max Players & Type Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _textFieldLabel('Límite de Jugadores'),
                        DropdownButtonFormField<int>(
                          value: _maxPlayers,
                          dropdownColor: const Color(0xff1B1625),
                          decoration: _inputDecoration(''),
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          items: [2, 4, 8, 16, 32, 64, 128].map((n) {
                            return DropdownMenuItem<int>(value: n, child: Text('$n jugadores'));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _maxPlayers = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _textFieldLabel('Estructura / Formato'),
                        DropdownButtonFormField<String>(
                          value: _formatType,
                          dropdownColor: const Color(0xff1B1625),
                          decoration: _inputDecoration(''),
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          items: const [
                            DropdownMenuItem(value: 'single_elimination', child: Text('Eliminación Simple')),
                            DropdownMenuItem(value: 'double_elimination', child: Text('Eliminación Doble')),
                            DropdownMenuItem(value: 'round_robin', child: Text('Round Robin')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _formatType = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date & Time Selectors Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _textFieldLabel('Fecha de Inicio'),
                        InkWell(
                          onTap: _selectDate,
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xff1A1625),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xff2d2543)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(DateFormat('dd MMM yyyy').format(_startDate), style: const TextStyle(color: Colors.white, fontSize: 14)),
                                const Icon(Icons.calendar_today_rounded, color: Colors.white30, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _textFieldLabel('Hora de Inicio'),
                        InkWell(
                          onTap: _selectTime,
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xff1A1625),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xff2d2543)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white, fontSize: 14)),
                                const Icon(Icons.access_time_rounded, color: Colors.white30, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Region & Privacy
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _textFieldLabel('Región de Servidor'),
                        DropdownButtonFormField<String>(
                          value: _region,
                          dropdownColor: const Color(0xff1B1625),
                          decoration: _inputDecoration(''),
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          items: const [
                            DropdownMenuItem(value: 'LATAM', child: Text('LATAM')),
                            DropdownMenuItem(value: 'NA', child: Text('NA')),
                            DropdownMenuItem(value: 'EU', child: Text('EU')),
                            DropdownMenuItem(value: 'GLOBAL', child: Text('Global')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _region = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _textFieldLabel('Acceso / Privacidad'),
                        DropdownButtonFormField<String>(
                          value: _privacy,
                          dropdownColor: const Color(0xff1B1625),
                          decoration: _inputDecoration(''),
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          items: const [
                            DropdownMenuItem(value: 'public', child: Text('Público Libre')),
                            DropdownMenuItem(value: 'private', child: Text('Privado con Clave')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _privacy = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Password if private
              if (_privacy == 'private') ...[
                _textFieldLabel('Contraseña de Inscripción *'),
                TextFormField(
                  controller: _passwordController,
                  validator: (val) => _privacy == 'private' && (val == null || val.trim().isEmpty) ? 'Requerido' : null,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _inputDecoration('Contraseña requerida para inscribirse'),
                ),
                const SizedBox(height: 16),
              ],

              // Is Official Switch if Admin
              if (isAdmin) ...[
                Row(
                  children: [
                    Switch(
                      value: _isOfficial,
                      activeColor: const Color(0xff7B4DFF),
                      onChanged: (val) {
                        setState(() {
                          _isOfficial = val;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Marcar como Torneo Oficial de GameVerse 🏆',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Rules
              _textFieldLabel('Reglas Especiales (Opcional)'),
              TextFormField(
                controller: _rulesController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _inputDecoration('Establece las reglas del torneo...'),
              ),
              const SizedBox(height: 16),

              // Prizes
              _textFieldLabel('Premios (Opcional)'),
              TextFormField(
                controller: _prizesController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _inputDecoration('Establece los premios para los ganadores...'),
              ),
              const SizedBox(height: 32),

              // Submit Button
              _submitting
                  ? const Center(child: CircularProgressIndicator(color: Color(0xff7B4DFF)))
                  : SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff6438FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 8,
                          shadowColor: const Color(0xff6438FF).withOpacity(0.4),
                        ),
                        child: const Text(
                          'Crear Torneo Arena',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(color: Color(0xff7B4DFF), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8),
        ),
        const SizedBox(height: 4),
        const Divider(color: Color(0xff2d2543), height: 1),
      ],
    );
  }

  Widget _textFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      filled: true,
      fillColor: const Color(0xff1A1625),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xff2d2543))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xff2d2543))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xff7B4DFF))),
    );
  }
}
