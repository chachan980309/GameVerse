import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/post_controller.dart';
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

  bool get _isOwnPost =>
      Supabase.instance.client.auth.currentUser?.id == post.userId;

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
              case "delete":
                _confirmDelete(context);
                break;

              case "report":
                break;

              case "share":
                showShareSheet(context, post);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: "share", child: Text("Compartir")),
            if (_isOwnPost)
              const PopupMenuItem(
                value: "delete",
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text(
                      "Eliminar publicación",
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              )
            else
              const PopupMenuItem(value: "report", child: Text("Reportar")),
          ],
        ),
      ],
    );
  }

  void _openProfile(BuildContext context) =>
      ProfileNavigationService.instance.openProfile(post.userId);

  Future<void> _confirmDelete(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xff211D31),
        title: const Text('Eliminar publicación'),
        content: const Text(
          'Esta acción no se puede deshacer. \u00bfDeseas continuar?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !context.mounted) return;

    try {
      await PostController.instance.deletePost(post.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Publicación eliminada.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo eliminar la publicación.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
