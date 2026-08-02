import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/post_model.dart';
import '../../services/profile_navigation_service.dart';
import 'share_sheet.dart';

class PostHeader extends StatelessWidget {
  final PostModel post;

  const PostHeader({super.key, required this.post});

  String timeAgo(DateTime date) {
    final difference = DateTime.now().difference(date);

    if (difference.inSeconds < 60) {
      return "Hace unos segundos";
    }

    if (difference.inMinutes < 60) {
      return "Hace ${difference.inMinutes} min";
    }

    if (difference.inHours < 24) {
      return "Hace ${difference.inHours} h";
    }

    if (difference.inDays < 7) {
      return "Hace ${difference.inDays} días";
    }

    return DateFormat("dd/MM/yyyy").format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => _openProfile(context),
          child: CircleAvatar(
            radius: 23,
            backgroundColor: const Color(0xff6438FF),
            backgroundImage: post.avatarUrl.isNotEmpty
                ? NetworkImage(post.avatarUrl)
                : null,
            child: post.avatarUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => _openProfile(context),
                child: Text(
                  post.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),

              const SizedBox(height: 3),

              Text(
                timeAgo(post.createdAt),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),

        PopupMenuButton<String>(
          color: const Color(0xff2A2538),
          icon: const Icon(Icons.more_horiz, color: Colors.white70),
          onSelected: (value) {
            switch (value) {
              case "report":
                break;

              case "share":
                showShareSheet(context, post);
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: "share", child: Text("Compartir")),
            PopupMenuItem(value: "report", child: Text("Reportar")),
          ],
        ),
      ],
    );
  }

  void _openProfile(BuildContext context) =>
      ProfileNavigationService.instance.openProfile(post.userId);
}
