import 'package:flutter/material.dart';

class ProfileTabs extends StatelessWidget {
  const ProfileTabs({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  static const _tabs = [
    ('Muro', Icons.forum_outlined),
    ('Juegos', Icons.sports_esports_outlined),
    ('Clips', Icons.ondemand_video_outlined),
    ('Fotos', Icons.photo_library_outlined),
    ('Información', Icons.info_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      decoration: const BoxDecoration(
        color: Color(0xFF15121F),
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_tabs.length, (index) {
          final selected = selectedIndex == index;
          final color = selected ? const Color(0xFFA78BFA) : Colors.white70;
          final tab = _tabs[index];

          return Tooltip(
            message: tab.$1,
            child: InkWell(
              onTap: () => onTabSelected(index),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF6D35F5).withValues(alpha: .20)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF8B5CF6).withValues(alpha: .5)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tab.$2, size: 18, color: color),
                    const SizedBox(width: 8),
                    Text(
                      tab.$1,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
