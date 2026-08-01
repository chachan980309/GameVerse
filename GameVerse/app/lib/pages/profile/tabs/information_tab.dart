import 'package:flutter/material.dart';

import '../../../controllers/profile_controller.dart';

class InformationTab extends StatelessWidget {
  const InformationTab({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileController.instance;
    return AnimatedBuilder(
      animation: profile,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1828),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF39324F)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.person_outline_rounded, color: Color(0xFF9A78FF)),
                const SizedBox(width: 9),
                Text('Acerca de ${profile.username}', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 14),
              Text(
                profile.bio.isEmpty ? 'Todavía no has añadido una biografía.' : profile.bio,
                style: const TextStyle(color: Colors.white70, height: 1.45),
              ),
              const SizedBox(height: 20),
              Wrap(spacing: 30, runSpacing: 16, children: [
                _detail(Icons.location_on_outlined, profile.location, 'Ubicación'),
                _detail(Icons.desktop_windows_outlined, profile.platform, 'Plataforma'),
                _detail(Icons.shield_outlined, profile.role, 'Rol gamer'),
                _detail(Icons.sports_esports_outlined, profile.favoriteGame, 'Juego favorito'),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String value, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: const Color(0xFF9A78FF), size: 18),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          Text(value.isEmpty ? 'Sin configurar' : value, style: const TextStyle(color: Colors.white70)),
        ]),
      ]);
}
