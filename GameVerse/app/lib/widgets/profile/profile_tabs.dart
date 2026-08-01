import 'package:flutter/material.dart';

class ProfileTabs extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabSelected;

  const ProfileTabs({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  static const tabs = ["Muro", "Juegos", "Clips", "Fotos", "Información"];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xff2A2A2A))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(tabs.length, (index) {
          final selected = selectedIndex == index;

          return InkWell(
            onTap: () => onTabSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    tabs[index],
                    style: TextStyle(
                      color: selected
                          ? const Color(0xff8B5CF6)
                          : Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: selected ? 45 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xff8B5CF6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
