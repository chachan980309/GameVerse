import 'package:flutter/material.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,

      padding: const EdgeInsets.symmetric(horizontal: 25),

      decoration: BoxDecoration(
        color: const Color(0xff111019),

        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: .06)),
        ),
      ),

      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,

              decoration: BoxDecoration(
                color: const Color(0xff211D2E),

                borderRadius: BorderRadius.circular(15),
              ),

              child: const TextField(
                style: TextStyle(color: Colors.white, fontSize: 14),

                decoration: InputDecoration(
                  hintText: "Buscar jugadores, juegos o amigos...",

                  hintStyle: TextStyle(color: Colors.white54, fontSize: 13),

                  prefixIcon: Icon(
                    Icons.search,

                    color: Colors.white54,

                    size: 21,
                  ),

                  border: InputBorder.none,

                  contentPadding: EdgeInsets.only(top: 12),
                ),
              ),
            ),
          ),

          const SizedBox(width: 18),

          _iconButton(Icons.person_add_alt_1),

          const SizedBox(width: 10),

          _iconButton(Icons.chat_bubble_outline),

          const SizedBox(width: 10),

          _iconButton(Icons.notifications_none),

          const SizedBox(width: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

            decoration: BoxDecoration(
              color: const Color(0xff211D2E),

              borderRadius: BorderRadius.circular(14),
            ),

            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),

                  decoration: BoxDecoration(
                    shape: BoxShape.circle,

                    border: Border.all(
                      color: const Color(0xff7B4DFF),

                      width: 2,
                    ),
                  ),

                  child: const CircleAvatar(
                    radius: 18,

                    backgroundColor: Color(0xff6438FF),

                    child: Text(
                      "G",

                      style: TextStyle(
                        color: Colors.white,

                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 9),

                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      "Gio",

                      style: TextStyle(
                        color: Colors.white,

                        fontWeight: FontWeight.bold,

                        fontSize: 14,
                      ),
                    ),

                    Text(
                      "En línea",

                      style: TextStyle(color: Colors.greenAccent, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _iconButton(IconData icon) {
    return Container(
      width: 42,

      height: 42,

      decoration: BoxDecoration(
        color: const Color(0xff211D2E),

        borderRadius: BorderRadius.circular(13),
      ),

      child: Icon(icon, color: Colors.white70, size: 20),
    );
  }
}
