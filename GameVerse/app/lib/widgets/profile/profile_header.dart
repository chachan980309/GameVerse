import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app/widgets/profile/editable_banner.dart';
import 'package:app/widgets/profile/editable_avatar.dart';

class ProfileHeader extends StatefulWidget {
  const ProfileHeader({super.key});

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  final TextEditingController mottoController = TextEditingController();

  @override
  void dispose() {
    mottoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 270,

      child: Stack(
        clipBehavior: Clip.none,

        children: [
          // Banner
          const IgnorePointer(child: EditableBanner()),

          // Avatar
          Positioned(left: 35, bottom: -35, child: const EditableAvatar()),

          // Información jugador
          Positioned(
            left: 220,
            top: 75,

            child: SizedBox(
              width: 420,

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text(
                    "Gio",

                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Row(
                    children: [
                      Icon(Icons.circle, color: Colors.greenAccent, size: 11),

                      SizedBox(width: 7),

                      Text(
                        "En línea",

                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    "Nivel 5",

                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),

                  const SizedBox(height: 5),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),

                    child: const SizedBox(
                      width: 280,

                      child: LinearProgressIndicator(
                        value: .60,

                        minHeight: 6,

                        backgroundColor: Color(0xff353240),

                        valueColor: AlwaysStoppedAnimation(Color(0xff6E4CFF)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    "1200 / 2000 XP",

                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),

                  const SizedBox(height: 18),

                  // ==========================
                  // LEMA
                  // ==========================
                  SizedBox(
                    width: 320,
                    height: 32,

                    child: TextField(
                      controller: mottoController,

                      maxLength: 20,

                      inputFormatters: [
                        LengthLimitingTextInputFormatter(20),

                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9\s\-\_\!\#\.\,\*\$]+'),
                        ),
                      ],

                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                      ),

                      decoration: const InputDecoration(
                        counterText: "",

                        hintText: "Agregar lema...",

                        hintStyle: TextStyle(
                          color: Colors.white38,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                        ),

                        border: InputBorder.none,

                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Botones
          Positioned(
            right: 35,
            top: 125,

            child: Row(
              children: [
                ElevatedButton(
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

                const SizedBox(width: 12),

                OutlinedButton.icon(
                  onPressed: () {},

                  icon: const Icon(Icons.share, size: 18),

                  label: const Text("Compartir"),

                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,

                    side: BorderSide(
                      color: Colors.white.withValues(alpha: .15),
                    ),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
