import 'package:flutter/material.dart';

import 'editable_avatar.dart';

class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // TARJETA
          Container(
            margin: const EdgeInsets.only(top: 55),
            padding: const EdgeInsets.fromLTRB(170, 28, 24, 24),
            decoration: BoxDecoration(
              color: const Color(0xff1E1B29),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: .06)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // INFORMACIÓN
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Gio",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      const Row(
                        children: [
                          Icon(
                            Icons.circle,
                            color: Colors.greenAccent,
                            size: 10,
                          ),
                          SizedBox(width: 6),
                          Text(
                            "En línea",
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        "No soy pro, pero me divierto 🎮",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

                // BOTONES
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff6E4CFF),
                      ),
                      child: const Text(
                        "Editar perfil",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),

                    const SizedBox(width: 10),

                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text("Compartir"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // AVATAR
          const Positioned(left: 35, top: 0, child: EditableAvatar()),
        ],
      ),
    );
  }
}
