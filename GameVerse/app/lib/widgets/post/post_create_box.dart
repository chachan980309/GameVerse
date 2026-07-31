import 'package:app/controllers/profile_controller.dart';
import 'package:flutter/material.dart';

import 'create_post_dialog.dart';

class PostCreateBox extends StatelessWidget {
  const PostCreateBox({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileController();

    return AnimatedBuilder(
      animation: profile,
      builder: (context, _) {
        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            margin: const EdgeInsets.symmetric(vertical: 30),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xff23202E),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => const CreatePostDialog(),
                        );
                      },
                      child: CircleAvatar(
                        radius: 26,
                        backgroundImage:
                            profile.avatarUrl != null &&
                                profile.avatarUrl!.isNotEmpty
                            ? NetworkImage(profile.avatarUrl!)
                            : const AssetImage("assets/images/avatar.png")
                                  as ImageProvider,
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => const CreatePostDialog(),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xff2E2A3B),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            "¿Qué estás jugando hoy, ${profile.username}?",
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                const Divider(color: Color(0xff353142)),

                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _button(Icons.image_outlined, "Imagen", Colors.green),
                    _button(Icons.videocam_outlined, "Clip", Colors.redAccent),
                    _button(
                      Icons.emoji_emotions_outlined,
                      "Emoji",
                      Colors.amber,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _button(IconData icon, String text, Color color) {
    return TextButton.icon(
      onPressed: () {},
      icon: Icon(icon, color: color),
      label: Text(text, style: const TextStyle(color: Colors.white70)),
    );
  }
}
