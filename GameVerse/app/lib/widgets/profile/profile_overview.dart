import 'package:flutter/material.dart';

import 'editable_avatar.dart';

class ProfileOverview extends StatelessWidget {
  const ProfileOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 78),
            padding: const EdgeInsets.fromLTRB(210, 28, 30, 25),
            decoration: BoxDecoration(
              color: const Color(0xff1E1B29),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: .05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Gio",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          const Row(
                            children: [
                              Icon(
                                Icons.circle,
                                color: Colors.greenAccent,
                                size: 10,
                              ),

                              SizedBox(width: 8),

                              Text(
                                "En línea",
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          const Row(
                            children: [
                              Icon(
                                Icons.sports_esports,
                                color: Colors.white54,
                                size: 17,
                              ),

                              SizedBox(width: 8),

                              Text(
                                "Jugador desde 2025",
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 22),

                          const Text(
                            "No soy pro, pero me divierto 🎮",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Row(
                      children: [
                        SizedBox(
                          width: 145,
                          height: 42,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff6E4CFF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Editar perfil",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        SizedBox(
                          width: 145,
                          height: 42,
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text("Compartir"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: .18),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                const Divider(color: Color(0xff2B2835)),

                const SizedBox(height: 18),
                // ==========================
                // ESTADÍSTICAS
                // ==========================
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ProfileStat(value: "124", label: "Publicaciones"),

                    _ProfileStat(value: "250", label: "Amigos"),

                    _ProfileStat(value: "1.2K", label: "Seguidores"),

                    _ProfileStat(value: "320", label: "Siguiendo"),
                  ],
                ),

                const SizedBox(height: 24),

                const Divider(color: Color(0xff2B2835)),

                const SizedBox(height: 12),

                // Aquí después irán las pestañas
                const SizedBox(height: 10),
              ],
            ),
          ),

          // ==========================
          // AVATAR
          // ==========================
          const Positioned(left: 35, top: -15, child: EditableAvatar()),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;

  const _ProfileStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
