import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'editable_avatar.dart';

class ProfileInfo extends StatefulWidget {
  const ProfileInfo({super.key});

  @override
  State<ProfileInfo> createState() => _ProfileInfoState();
}

class _ProfileInfoState extends State<ProfileInfo> {
  final TextEditingController mottoController = TextEditingController();

  @override
  void dispose() {
    mottoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(35, 0, 35, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EditableAvatar(),

          const SizedBox(width: 28),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                const Text(
                  "Gio",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                const Row(
                  children: [
                    Icon(Icons.circle, color: Colors.greenAccent, size: 11),
                    SizedBox(width: 7),
                    Text(
                      "En línea",
                      style: TextStyle(color: Colors.greenAccent, fontSize: 14),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                const Text(
                  "Nivel 5",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),

                const SizedBox(height: 6),

                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: const SizedBox(
                    width: 320,
                    child: LinearProgressIndicator(
                      value: .60,
                      minHeight: 6,
                      backgroundColor: Color(0xff353240),
                      valueColor: AlwaysStoppedAnimation(Color(0xff6E4CFF)),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  "1200 / 2000 XP",
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: 340,
                  child: TextField(
                    controller: mottoController,
                    maxLength: 20,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(20),
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9\s\-_!#.,*$]+'),
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
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 20),

          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Row(
              children: [
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff6E4CFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text("Compartir"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white24),
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
