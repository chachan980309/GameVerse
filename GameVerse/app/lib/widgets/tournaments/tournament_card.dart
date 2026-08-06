import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/tournament_model.dart';
import '../../pages/tournament_detail_page.dart';

class TournamentCard extends StatefulWidget {
  final TournamentModel tournament;

  const TournamentCard({super.key, required this.tournament});

  @override
  State<TournamentCard> createState() => _TournamentCardState();
}

class _TournamentCardState extends State<TournamentCard> {
  bool _isHovered = false;

  Color _getStatusColor(String status) {
    switch (status) {
      case 'registration':
        return const Color(0xff50E6A5); // Green
      case 'full':
        return Colors.orange; // Orange
      case 'in_progress':
        return const Color(0xffffb800); // Yellow
      case 'finished':
        return Colors.white54;
      case 'cancelled':
        return const Color(0xffD64A68); // Red
      case 'archived':
        return Colors.white30;
      default:
        return const Color(0xff6438FF); // Purple
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'draft':
        return 'Borrador';
      case 'registration':
        return 'Inscripciones';
      case 'full':
        return 'Lleno';
      case 'in_progress':
        return 'En Vivo 🔴';
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

  Widget _badge({
    required String text,
    required Color color,
    Color? borderColor,
    Color textColor = Colors.white,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: borderColor != null ? Border.all(color: borderColor.withOpacity(0.4)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: textColor, size: 10),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Alignment _getFocalPoint(String gameName) {
    final name = gameName.toLowerCase().trim();
    if (name.contains('fortnite')) {
      return Alignment.topCenter;
    }
    if (name.contains('valorant')) {
      return Alignment.center;
    }
    if (name.contains('league of legends') || name == 'lol') {
      return Alignment.center;
    }
    if (name.contains('minecraft')) {
      return Alignment.center;
    }
    if (name.contains('counter-strike') || name.contains('cs2') || name == 'cs') {
      return Alignment.center;
    }
    return Alignment.center; // Focal point por defecto
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(widget.tournament.status);
    final isFull = widget.tournament.participantCount >= widget.tournament.maxPlayers;
    final imageUrl = widget.tournament.gameHeroUrl;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Transform.translate(
        offset: Offset(0, _isHovered ? -8 : 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: const Color(0xff15121F),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.tournament.isOfficial 
                  ? const Color(0xff7B4DFF).withOpacity(_isHovered ? 0.9 : 0.3) 
                  : const Color(0xff2d2543).withOpacity(_isHovered ? 0.8 : 0.3),
              width: widget.tournament.isOfficial ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.tournament.isOfficial 
                    ? const Color(0xff7B4DFF).withOpacity(_isHovered ? 0.35 : 0.05)
                    : Colors.black.withOpacity(_isHovered ? 0.6 : 0.3),
                blurRadius: _isHovered ? 24 : 10,
                offset: Offset(0, _isHovered ? 12 : 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TournamentDetailPage(tournamentId: widget.tournament.id),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Imagen Protagónica Horizontal (Ocupa exactamente el 78% de la tarjeta)
                Expanded(
                  flex: 78,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Video Game Horizontal/Landscape Cover Art (heroImage)
                      ClipRRect(
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
                        child: SizedBox.expand(
                          child: AnimatedScale(
                            scale: _isHovered ? 1.08 : 1.0,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOut,
                            child: imageUrl != null && imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    alignment: _getFocalPoint(widget.tournament.gameName),
                                    errorBuilder: (ctx, err, stack) => _buildDefaultGradient(),
                                  )
                                : _buildDefaultGradient(),
                          ),
                        ),
                      ),
                      
                      // Dark Vignette gradient to overlay badges cleanly
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Color(0xff15121F), // Fades to bottom stripe color
                              Colors.transparent,
                              Color(0x99000000), // Shadow at top for badge contrast
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      
                      // Badges Top Row (OFICIAL/COMUNIDAD y REGION) - Flotando sobre el arte
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (widget.tournament.isOfficial)
                              _badge(
                                text: 'OFICIAL',
                                color: const Color(0xff6438FF),
                                icon: Icons.verified_rounded,
                              )
                            else
                              _badge(
                                text: 'COMUNIDAD',
                                color: Colors.black54,
                              ),
                            _badge(
                              text: widget.tournament.region.toUpperCase(),
                              color: const Color(0xff1A1625).withOpacity(0.85),
                              borderColor: const Color(0xff50E6A5),
                              textColor: const Color(0xff50E6A5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 2. Franja de Información Inferior Premium (Ocupa exactamente el 22% de la tarjeta / ~64 px)
                Expanded(
                  flex: 22,
                  child: Container(
                    color: const Color(0xff15121F),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Línea 1: Nombre del Torneo & Indicador Compacto de Jugadores
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.tournament.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.tournament.participantCount}/${widget.tournament.maxPlayers}',
                              style: TextStyle(
                                color: isFull ? const Color(0xffD64A68) : const Color(0xff50E6A5),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        
                        // Línea 2: Videojuego, Fecha & Estado Compacto
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${widget.tournament.gameName}  ·  ${DateFormat('dd MMM · HH:mm').format(widget.tournament.startDate.toLocal())}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, color: statusColor, size: 6),
                                const SizedBox(width: 4),
                                Text(
                                  _getStatusText(widget.tournament.status).toUpperCase(),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff2A1B54), Color(0xff120E22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.emoji_events_rounded, color: Colors.white24, size: 54),
      ),
    );
  }
}
