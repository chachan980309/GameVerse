import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/profile_controller.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  Widget _menuItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final active = selected == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xff6438FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
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

    return Container(
      width: 240,
      color: selected == 0 || selected == 1 || selected == 3 || selected == 5
          ? const Color.fromRGBO(8, 9, 16, 0.88)
          : const Color(0xff0D0E15),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            const Text(
              '🎮 nubzzz',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xff7B4DFF), width: 2),
              ),
              child: CircleAvatar(
                radius: 42,
                backgroundColor: const Color(0xff6438FF),
                backgroundImage: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                    ? NetworkImage(profile.avatarUrl!)
                    : null,
                child: profile.avatarUrl == null || profile.avatarUrl!.isEmpty
                    ? const Icon(Icons.person, size: 48, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              profile.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
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
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xff1B1926),
                borderRadius: BorderRadius.circular(14),
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
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xff7B4DFF),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Nivel ${profile.level} · ${profile.xpInCurrentLevel}/250 XP',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
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
            _menuItem(icon: Icons.settings_rounded, title: 'Ajustes', index: 6),
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
}
