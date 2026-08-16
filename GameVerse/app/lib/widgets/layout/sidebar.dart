import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/profile_controller.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.selected,
    required this.onSelected,
    this.compact = false,
  });

  final int selected;
  final ValueChanged<int> onSelected;
  final bool compact;

  // ============================================================
  // ITEM DEL MENÚ
  // ============================================================

  Widget _menuItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final active = selected == index;

    if (compact) {
      return Tooltip(
        message: title,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? const Color(0xff6438FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () => onSelected(index),
            icon: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xff6438FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: active
            ? [
                BoxShadow(
                  color: const Color(0xff6438FF).withOpacity(0.25),
                  blurRadius: 12,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: () => onSelected(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<ProfileController>(context);

    if (compact) return _compactSidebar(profile);

    return Container(
      width: double.infinity,
      color: selected == 0 || selected == 1 || selected == 3 || selected == 5
          ? const Color.fromRGBO(8, 9, 16, 0.88)
          : const Color(0xff0D0E15),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),

            // ====================================================
            // LOGO NUBZZZ
            // ====================================================
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ICONO GAMER
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xff6438FF),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff6438FF).withOpacity(0.55),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.sports_esports_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),

                    const SizedBox(width: 9),

                    // NUBZZZ
                    Text(
                      'NUBZZZ',
                      style: TextStyle(
                        fontFamily: 'NubzzzGamer',
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.normal,
                        letterSpacing: 1.0,
                        height: 1.0,
                        shadows: [
                          Shadow(
                            color: const Color(0xff8B4DFF).withOpacity(0.95),
                            blurRadius: 12,
                            offset: const Offset(0, 0),
                          ),
                          Shadow(
                            color: const Color(0xff6438FF).withOpacity(0.55),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                          const Shadow(
                            color: Color(0xff120A24),
                            blurRadius: 3,
                            offset: Offset(1, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                // SUBTÍTULO
                Text(
                  'TU JUEGO · TU COMUNIDAD',
                  style: TextStyle(
                    color: const Color(0xff914DFF),
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.35,
                    height: 1.0,
                    shadows: [
                      Shadow(
                        color: const Color(0xff6438FF).withOpacity(0.7),
                        blurRadius: 7,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            // ====================================================
            // FOTO DE PERFIL
            // ====================================================
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xff7B4DFF), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff6438FF).withOpacity(0.25),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 42,
                backgroundColor: const Color(0xff6438FF),
                backgroundImage:
                    profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                    ? NetworkImage(profile.avatarUrl!)
                    : null,
                child: profile.avatarUrl == null || profile.avatarUrl!.isEmpty
                    ? const Icon(Icons.person, size: 48, color: Colors.white)
                    : null,
              ),
            ),

            const SizedBox(height: 10),

            // ====================================================
            // USUARIO
            // ====================================================
            Text(
              profile.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            // ====================================================
            // ESTADO
            // ====================================================
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.circle, color: Colors.greenAccent, size: 8),
                SizedBox(width: 5),
                Text(
                  'En línea',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 11),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ====================================================
            // XP
            // ====================================================
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xff1B1926),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xff2A263A)),
              ),
              child: Column(
                children: [
                  Text(
                    '⚡ ${profile.xp} XP',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: profile.levelProgress,
                      minHeight: 5,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xff7B4DFF),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Nivel ${profile.level} · '
                    '${profile.xpInCurrentLevel}/250 XP',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ====================================================
            // MENÚ PRINCIPAL
            // ====================================================
            _menuItem(icon: Icons.home_rounded, title: 'Inicio', index: 0),

            _menuItem(icon: Icons.person_rounded, title: 'Perfil', index: 1),

            _menuItem(icon: Icons.people_rounded, title: 'Amigos', index: 2),

            _menuItem(
              icon: Icons.graphic_eq_rounded,
              title: 'Canales de voz',
              index: 3,
            ),

            _menuItem(
              icon: Icons.emoji_events_rounded,
              title: 'Torneos',
              index: 4,
            ),

            _menuItem(icon: Icons.fort_rounded, title: 'Clanes', index: 5),

            // ====================================================
            // ESPACIO INFERIOR
            // ====================================================
            const Spacer(),

            const Text(
              'v1.0',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),

            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  Widget _compactSidebar(ProfileController profile) => Container(
    color: selected == 0 || selected == 1 || selected == 3 || selected == 5
        ? const Color.fromRGBO(8, 9, 16, 0.92)
        : const Color(0xff0D0E15),
    child: SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xff6438FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.sports_esports_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xff6438FF),
            backgroundImage: profile.avatarUrl?.isNotEmpty == true
                ? NetworkImage(profile.avatarUrl!)
                : null,
            child: profile.avatarUrl?.isNotEmpty == true
                ? null
                : const Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(height: 16),
          _menuItem(icon: Icons.home_rounded, title: 'Inicio', index: 0),
          _menuItem(icon: Icons.person_rounded, title: 'Perfil', index: 1),
          _menuItem(icon: Icons.people_rounded, title: 'Amigos', index: 2),
          _menuItem(
            icon: Icons.graphic_eq_rounded,
            title: 'Canales de voz',
            index: 3,
          ),
          _menuItem(
            icon: Icons.emoji_events_rounded,
            title: 'Torneos',
            index: 4,
          ),
          _menuItem(icon: Icons.fort_rounded, title: 'Clanes', index: 5),
          const Spacer(),
          const Text(
            'v1.0',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
          const SizedBox(height: 14),
        ],
      ),
    ),
  );
}
