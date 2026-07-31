import 'package:app/controllers/profile_controller.dart';
import 'package:flutter/material.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileController();

    return AnimatedBuilder(
      animation: profile,
      builder: (context, _) {
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

              const SizedBox(width: 22),

              Row(
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
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xff6438FF),
                      backgroundImage:
                          profile.avatarUrl != null &&
                              profile.avatarUrl!.isNotEmpty
                          ? NetworkImage(profile.avatarUrl!)
                          : const AssetImage("assets/images/avatar.png")
                                as ImageProvider,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),

                          const SizedBox(width: 6),

                          Text(
                            profile.status,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
