import 'package:flutter/material.dart';

import '../../models/direct_message.dart';
import '../../models/post_model.dart';
import '../../pages/post_detail_page.dart';
import '../../services/post_service.dart';
import '../mention_text.dart';

/// Burbuja reutilizable: un mensaje normal o una publicación compartida.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.mine,
  });

  final DirectMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final sharedPostId = message.sharedPostId;
    if (sharedPostId == null || sharedPostId.isEmpty) {
      return _bubble(
        Text(message.content, style: const TextStyle(color: Colors.white)),
      );
    }

    return FutureBuilder<PostModel?>(
      future: PostService().getPostById(sharedPostId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _bubble(
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          );
        }
        final post = snapshot.data;
        if (post == null) {
          return _bubble(
            const Text(
              'Esta publicación ya no está disponible.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return InkWell(
          onTap: () {
            // Una tarjeta compartida abre la publicación original en su propia
            // vista. Así el chat queda intacto al volver atrás y nunca se
            // pierde el post entre los elementos del feed.
            final originalPostId = post.sharedPost?.id ?? post.id;
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => PostDetailPage(postId: originalPostId),
              ),
            );
          },
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(14),
          child: _bubble(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: const Color(0xFF6D35F5),
                      backgroundImage: post.avatarUrl.isEmpty
                          ? null
                          : NetworkImage(post.avatarUrl),
                      child: post.avatarUrl.isEmpty
                          ? const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        post.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (post.content.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  MentionText(
                    text: post.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, height: 1.35),
                  ),
                ],
                if (post.imageUrl?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      post.imageUrl!,
                      height: 126,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 14,
                      color: Color(0xFFC5B4FF),
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Ver publicación',
                      style: TextStyle(color: Color(0xFFC5B4FF), fontSize: 12),
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

  Widget _bubble(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    constraints: const BoxConstraints(maxWidth: 360),
    decoration: BoxDecoration(
      color: mine ? const Color(0xFF5630CD) : const Color(0xFF292437),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: message.sharedPostId == null
            ? Colors.transparent
            : const Color(0xFF6D35F5),
      ),
    ),
    child: child,
  );
}
