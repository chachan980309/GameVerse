import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tournament_model.dart';
import '../models/tournament_bracket_match.dart';
import '../controllers/profile_controller.dart';
import '../controllers/tournament_controller.dart';
import '../services/tournament_service.dart';

class TournamentDetailPage extends StatefulWidget {
  final String tournamentId;

  const TournamentDetailPage({super.key, required this.tournamentId});

  @override
  State<TournamentDetailPage> createState() => _TournamentDetailPageState();
}

class _TournamentDetailPageState extends State<TournamentDetailPage>
    with SingleTickerProviderStateMixin {
  final TournamentController _controller = TournamentController.instance;
  final TournamentService _service = TournamentService();

  late TabController _tabController;
  TournamentModel? _tournament;
  bool _loading = true;
  bool _submitting = false;
  List<TournamentBracketMatch> _bracketMatches = const [];
  bool _bracketLoading = false;
  RealtimeChannel? _bracketSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTournamentDetails();
    _subscribeBracketRealtime();
    _controller.addListener(_onControllerStateChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bracketSubscription?.unsubscribe();
    _controller.removeListener(_onControllerStateChanged);
    super.dispose();
  }

  void _subscribeBracketRealtime() {
    _bracketSubscription = Supabase.instance.client
        .channel('tournament-bracket-${widget.tournamentId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tournament_matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'tournament_id',
            value: widget.tournamentId,
          ),
          callback: (_) => _loadBracket(),
        )
        .subscribe();
  }

  void _onControllerStateChanged() {
    final index = _controller.tournaments.indexWhere(
      (t) => t.id == widget.tournamentId,
    );
    if (index != -1 && mounted) {
      setState(() {
        _tournament = _controller.tournaments[index];
      });
    }
  }

  Future<void> _loadTournamentDetails() async {
    setState(() => _loading = true);
    final data = await _service.getTournamentById(widget.tournamentId);
    if (mounted) {
      setState(() {
        _tournament = data;
        _loading = false;
      });
      if (data != null) _loadBracket();
    }
  }

  Future<void> _loadBracket() async {
    if (_tournament == null) return;
    setState(() => _bracketLoading = true);
    try {
      final matches = await _service.getBracketMatches(_tournament!.id);
      if (mounted) setState(() => _bracketMatches = matches);
    } finally {
      if (mounted) setState(() => _bracketLoading = false);
    }
  }

  Future<void> _startTournamentWithBracket() async {
    setState(() => _loading = true);
    try {
      await _controller.initializeBracket(_tournament!.id);
      await _loadTournamentDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Llave generada y participantes mezclados al azar.'),
            backgroundColor: Color(0xff50E6A5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo iniciar: $e'),
            backgroundColor: const Color(0xffD64A68),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isJoined {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null || _tournament == null) return false;
    return _tournament!.participants.any((p) => p.userId == currentUserId);
  }

  Future<void> _toggleParticipation() async {
    if (_tournament == null || _submitting) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    // Bloquear participación en torneos inactivos
    if (_tournament!.status == 'cancelled' ||
        _tournament!.status == 'finished' ||
        _tournament!.status == 'archived') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No te puedes inscribir en un torneo inactivo.'),
          backgroundColor: Color(0xffD64A68),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      if (_isJoined) {
        await _controller.leaveTournament(_tournament!.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Has abandonado el torneo.'),
            backgroundColor: Color(0xffD64A68),
          ),
        );
      } else {
        if (_tournament!.participantCount >= _tournament!.maxPlayers) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El torneo está lleno.'),
              backgroundColor: Color(0xffD64A68),
            ),
          );
          return;
        }
        await _controller.joinTournament(_tournament!.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Te has inscrito con éxito!'),
            backgroundColor: Color(0xff50E6A5),
          ),
        );
      }
      await _loadTournamentDetails();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar inscripción: $e'),
          backgroundColor: const Color(0xffD64A68),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showReportDialog() async {
    final reasons = [
      {'id': 'spam', 'label': 'Spam / Publicidad molesta'},
      {'id': 'offensive', 'label': 'Contenido ofensivo / Odio'},
      {'id': 'fake_info', 'label': 'Información falsa / Engaño'},
      {'id': 'scam', 'label': 'Estafa / Fraude'},
      {'id': 'other', 'label': 'Otro motivo'},
    ];
    String selectedReason = 'spam';
    final detailsController = TextEditingController();

    final success = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xff1B1625),
            title: const Text(
              'Reportar Torneo',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecciona el motivo del reporte:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    dropdownColor: const Color(0xff1B1625),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xff130F1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: reasons.map((r) {
                      return DropdownMenuItem(
                        value: r['id'],
                        child: Text(r['label']!),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedReason = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Detalles del reporte (Opcional):',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: detailsController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Describe brevemente el problema...',
                      hintStyle: const TextStyle(
                        color: Colors.white24,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: const Color(0xff130F1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xffD64A68),
                ),
                child: const Text('Enviar Reporte'),
              ),
            ],
          );
        },
      ),
    );

    if (success == true) {
      try {
        await _controller.reportTournament(
          _tournament!.id,
          selectedReason,
          detailsController.text.trim(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '¡Gracias! El torneo ha sido reportado para revisión.',
            ),
            backgroundColor: Color(0xff50E6A5),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar reporte: $e'),
            backgroundColor: const Color(0xffD64A68),
          ),
        );
      }
    }
  }

  Future<void> _updateStatus(String newStatus, String actionLabel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff1B1625),
        title: Text('¿$actionLabel torneo?'),
        content: Text('Esto cambiará el estado del torneo a "$newStatus".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff7B4DFF),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        await _controller.updateTournamentStatus(_tournament!.id, newStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Torneo actualizado a "$newStatus"'),
            backgroundColor: const Color(0xff50E6A5),
          ),
        );
        await _loadTournamentDetails();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: const Color(0xffD64A68),
          ),
        );
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'draft':
        return 'Borrador';
      case 'registration':
        return 'Inscripciones';
      case 'full':
        return 'Cupos Llenos';
      case 'in_progress':
        return 'En Curso 🔴';
      case 'finished':
        return 'Finalizado';
      case 'cancelled':
        return 'Cancelado';
      case 'archived':
        return 'Archivado';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'registration':
        return const Color(0xff50E6A5);
      case 'full':
        return Colors.orange;
      case 'in_progress':
        return const Color(0xffffb800);
      case 'finished':
        return Colors.white54;
      case 'cancelled':
        return const Color(0xffD64A68);
      default:
        return const Color(0xff7B4DFF);
    }
  }

  String _getTypeText(String type) {
    switch (type) {
      case 'single_elimination':
        return 'Eliminación Simple';
      case 'double_elimination':
        return 'Eliminación Doble';
      case 'round_robin':
        return 'Round Robin';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xff130F1A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xff7B4DFF)),
        ),
      );
    }

    if (_tournament == null) {
      return const Scaffold(
        backgroundColor: Color(0xff130F1A),
        body: Center(
          child: Text(
            'Torneo no encontrado',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final isFull = _tournament!.participantCount >= _tournament!.maxPlayers;
    final isOwner =
        _tournament!.creatorId == Supabase.instance.client.auth.currentUser?.id;
    final isAdmin = ProfileController.instance.role == 'Admin';

    return Scaffold(
      backgroundColor: const Color(0xff130F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xff1A1625),
        elevation: 0,
        title: Text(
          _tournament!.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          if (!isOwner)
            IconButton(
              icon: const Icon(
                Icons.report_problem_outlined,
                color: Colors.amber,
              ),
              tooltip: 'Reportar Torneo',
              onPressed: _showReportDialog,
            ),
        ],
      ),
      body: Column(
        children: [
          // Banner Frame with Blur Backing (Steam-style)
          SizedBox(
            height: 180,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Imagen de fondo borrosa
                if (_tournament!.gameBackgroundUrl != null &&
                    _tournament!.gameBackgroundUrl!.isNotEmpty)
                  ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Opacity(
                      opacity: 0.35,
                      child: Image.network(
                        _tournament!.gameBackgroundUrl!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xff39226B), Color(0xff120E1C)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                // 2. Imagen de primer plano nítida y completa (BoxFit.contain)
                if (_tournament!.gameBackgroundUrl != null &&
                    _tournament!.gameBackgroundUrl!.isNotEmpty)
                  Center(
                    child: Image.network(
                      _tournament!.gameBackgroundUrl!,
                      fit: BoxFit.contain,
                    ),
                  ),

                // Vignette gradient overlay
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xff130F1A), Colors.transparent],
                    ),
                  ),
                ),

                // Info Overlay on Banner
                Positioned(
                  bottom: 16,
                  left: 24,
                  right: 24,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xff6438FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _tournament!.gameName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _tournament!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),

                      // Status Label on Banner
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xff2d2543)),
                        ),
                        child: Text(
                          _getStatusText(_tournament!.status).toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(_tournament!.status),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Controls Action Row (Join / Leave)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CUPOS RESERVADOS',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.38),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_tournament!.participantCount} / ${_tournament!.maxPlayers} Jugadores inscritos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Join/Leave button
                _submitting
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: CircularProgressIndicator(
                          color: Color(0xff7B4DFF),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _toggleParticipation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isJoined
                              ? const Color(0xffD64A68) // Red for Leave
                              : (isFull
                                    ? Colors.white24
                                    : const Color(
                                        0xff50E6A5,
                                      )), // Green for Join
                          foregroundColor: _isJoined || isFull
                              ? Colors.white70
                              : const Color(0xff120F19),
                          minimumSize: const Size(160, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 6,
                          shadowColor: _isJoined
                              ? const Color(0xffD64A68).withOpacity(0.3)
                              : const Color(0xff50E6A5).withOpacity(0.3),
                        ),
                        child: Text(
                          _isJoined
                              ? 'Salir del Torneo'
                              : (isFull ? 'Lleno' : 'Inscribirse'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
              ],
            ),
          ),

          // Tabs headers
          Container(
            color: const Color(0xff1A1625),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xff7B4DFF),
              labelColor: const Color(0xff7B4DFF),
              unselectedLabelColor: Colors.white38,
              tabs: const [
                Tab(text: 'Información'),
                Tab(text: 'Participantes'),
                Tab(text: 'Brackets'),
              ],
            ),
          ),

          // Tabs Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_infoTab(), _participantsTab(), _bracketsTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _organizerControlPanel(bool isOwner, bool isAdmin) {
    final canDelete =
        !_tournament!.isOfficial &&
        _tournament!.startDate.isAfter(DateTime.now()) &&
        _tournament!.participantCount < 4;
    final canCancel =
        _tournament!.status != 'cancelled' &&
        _tournament!.status != 'finished' &&
        _tournament!.status != 'archived' &&
        (!_tournament!.isOfficial || isAdmin);
    final canStart =
        _tournament!.status == 'registration' &&
        (!_tournament!.isOfficial || isAdmin);
    final canFinish =
        _tournament!.status == 'in_progress' &&
        (!_tournament!.isOfficial || isAdmin);
    final canArchive =
        (_tournament!.status == 'finished' ||
            _tournament!.status == 'cancelled') &&
        (!_tournament!.isOfficial || isAdmin);

    if (!isOwner && !isAdmin) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff1F1B2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xff7B4DFF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.admin_panel_settings_rounded,
                color: Color(0xff7B4DFF),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Panel de Control del Organizador',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Iniciar Torneo
              if (canStart)
                ElevatedButton.icon(
                  onPressed: _tournament!.type == 'single_elimination'
                      ? _startTournamentWithBracket
                      : () => _updateStatus('in_progress', 'Iniciar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff50E6A5),
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text(
                    'Iniciar Torneo',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              // Finalizar Torneo
              if (canFinish)
                ElevatedButton.icon(
                  onPressed: () => _updateStatus('finished', 'Finalizar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff6438FF),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.emoji_events_rounded, size: 16),
                  label: const Text(
                    'Finalizar',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              // Cancelar Torneo (Cambia estado a cancelled, no borra de la DB)
              if (canCancel)
                ElevatedButton.icon(
                  onPressed: () => _updateStatus('cancelled', 'Cancelar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffD64A68),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.cancel_rounded, size: 16),
                  label: const Text(
                    'Cancelar',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              // Archivar Torneo
              if (canArchive)
                ElevatedButton.icon(
                  onPressed: () => _updateStatus('archived', 'Archivar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white30,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.archive_rounded, size: 16),
                  label: const Text(
                    'Archivar',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              // Eliminar Torneo (Físicamente de la DB)
              if (canDelete)
                ElevatedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xff1B1625),
                        title: const Text('¿Eliminar torneo físicamente?'),
                        content: const Text(
                          'Esta acción borrará de forma permanente el torneo del sistema.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xffD64A68),
                            ),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _controller.deleteTournament(_tournament!.id);
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffD64A68).withOpacity(0.1),
                    foregroundColor: const Color(0xffD64A68),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded, size: 16),
                  label: const Text(
                    'Eliminar Torneo',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _organizerReputationCard() {
    return FutureBuilder<OrganizerStatsModel?>(
      future: _service.getOrganizerStats(_tournament!.creatorId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null)
          return const SizedBox.shrink();
        final stats = snapshot.data!;

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xff161224),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xff2d2543)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ORGANIZADOR',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xff6438FF),
                    backgroundImage: _tournament!.creatorAvatar.isNotEmpty
                        ? NetworkImage(_tournament!.creatorAvatar)
                        : null,
                    child: _tournament!.creatorAvatar.isEmpty
                        ? Text(
                            _tournament!.creatorName.isNotEmpty
                                ? _tournament!.creatorName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tournament!.creatorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${stats.rating} / 5.0 Reputación',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xff2d2543), height: 1),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem('Creados', stats.createdCount),
                  _statItem('Finalizados', stats.finishedCount),
                  _statItem('Cancelados', stats.cancelledCount),
                  _statItem('Inscritos', stats.totalParticipants),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statItem(String label, int val) {
    return Column(
      children: [
        Text(
          val.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Widget _infoTab() {
    final isOwner =
        _tournament!.creatorId == Supabase.instance.client.auth.currentUser?.id;
    final isAdmin = ProfileController.instance.role == 'Admin';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _organizerControlPanel(isOwner, isAdmin),
          _organizerReputationCard(),
          _sectionTitle('Descripción'),
          const SizedBox(height: 8),
          Text(
            _tournament!.description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle('Información Básica'),
          const SizedBox(height: 12),
          _infoRow(
            Icons.grid_view_rounded,
            'Formato',
            _getTypeText(_tournament!.type),
          ),
          _infoRow(
            Icons.calendar_today_rounded,
            'Fecha y hora',
            DateFormat(
              'dd MMMM yyyy · HH:mm',
            ).format(_tournament!.startDate.toLocal()),
          ),
          _infoRow(Icons.public_rounded, 'Región', _tournament!.region),
          _infoRow(
            Icons.shield_outlined,
            'Acceso',
            _tournament!.privacy == 'private'
                ? 'Privado con Contraseña'
                : 'Público Libre',
          ),
          const SizedBox(height: 24),
          if (_tournament!.rules != null && _tournament!.rules!.isNotEmpty) ...[
            _sectionTitle('Reglas Oficiales'),
            const SizedBox(height: 8),
            Text(
              _tournament!.rules!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (_tournament!.prizes != null &&
              _tournament!.prizes!.isNotEmpty) ...[
            _sectionTitle('Premios 🎁'),
            const SizedBox(height: 8),
            Text(
              _tournament!.prizes!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white30, size: 18),
          const SizedBox(width: 12),
          Text(
            '$title:',
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _participantsTab() {
    if (_tournament!.participants.isEmpty) {
      return const Center(
        child: Text(
          'Ningún jugador inscrito aún.',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tournament!.participants.length,
      itemBuilder: (context, index) {
        final p = _tournament!.participants[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xff1A1625),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xff2d2543)),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xff6438FF),
              backgroundImage: p.avatarUrl.isNotEmpty
                  ? NetworkImage(p.avatarUrl)
                  : null,
              child: p.avatarUrl.isEmpty
                  ? Text(
                      p.username.isNotEmpty ? p.username[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white),
                    )
                  : null,
            ),
            title: Text(
              p.username,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Inscrito el ${DateFormat('dd MMM · HH:mm').format(p.joinedAt.toLocal())}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            trailing: const Icon(
              Icons.verified_user_rounded,
              color: Color(0xff50E6A5),
              size: 18,
            ),
          ),
        );
      },
    );
  }

  Widget _bracketsTab() {
    if (_bracketLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xff7B4DFF)),
      );
    }
    if (_bracketMatches.isEmpty) {
      return const Center(
        child: Text(
          'La llave se genera al iniciar el torneo.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    final byRound = <int, List<TournamentBracketMatch>>{};
    for (final match in _bracketMatches) {
      byRound.putIfAbsent(match.roundNumber, () => []).add(match);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var round = 1; round <= byRound.length; round++) ...[
                _buildBracketRound(
                  _roundTitle(round, byRound.length),
                  byRound[round]!.map(_matchNode).toList(),
                ),
                if (round < byRound.length) _bracketConnectorLine(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBracketRound(String title, List<Widget> matches) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xff7B4DFF),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 24),
        ...matches.map(
          (m) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: m,
          ),
        ),
      ],
    );
  }

  Widget _bracketConnectorLine() {
    return Container(width: 40, height: 2, color: const Color(0xff2d2543));
  }

  String _roundTitle(int round, int totalRounds) {
    if (round == totalRounds) return 'GRAN FINAL';
    return 'RONDA ${round.toString()}';
  }

  Widget _matchNode(TournamentBracketMatch match) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = currentUserId == _tournament!.creatorId;
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: const Color(0xff1A1625),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xff2d2543)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xff241D35),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(9),
                topRight: Radius.circular(9),
              ),
            ),
            child: Text(
              'Match ${match.matchNumber}',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _participantNodeRow(
            match.playerOneName ?? 'Por definir',
            isWinner: match.winnerId == match.playerOneId,
          ),
          const Divider(color: Color(0xff2d2543), height: 1),
          _participantNodeRow(
            match.playerTwoName ?? 'Por definir',
            isWinner: match.winnerId == match.playerTwoId,
          ),
          if (isOwner &&
              !match.isCompleted &&
              match.playerOneId != null &&
              match.playerTwoId != null)
            Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  Expanded(
                    child: _winnerButton(
                      match,
                      match.playerOneId!,
                      match.playerOneName ?? 'Jugador 1',
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _winnerButton(
                      match,
                      match.playerTwoId!,
                      match.playerTwoName ?? 'Jugador 2',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _winnerButton(
    TournamentBracketMatch match,
    String playerId,
    String name,
  ) {
    return OutlinedButton(
      onPressed: () async {
        await _service.reportMatchWinner(match.id, playerId);
        await _loadBracket();
        await _loadTournamentDetails();
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        side: const BorderSide(color: Color(0xff7B4DFF)),
      ),
      child: Text(
        name,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 9),
      ),
    );
  }

  Widget _participantNodeRow(String username, {bool isWinner = false}) {
    final isTbd = username == 'Por definir';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        username,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isWinner
              ? const Color(0xff50E6A5)
              : (isTbd ? Colors.white30 : Colors.white),
          fontSize: 12,
          fontWeight: isTbd ? FontWeight.normal : FontWeight.bold,
        ),
      ),
    );
  }
}
