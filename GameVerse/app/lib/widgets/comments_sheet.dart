import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/comment_service.dart';
import '../services/profile_navigation_service.dart';
import 'mention_text.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;
  final VoidCallback? onCommentAdded;

  const CommentsSheet({super.key, required this.postId, this.onCommentAdded});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final CommentService commentService = CommentService();

  final TextEditingController controller = TextEditingController();

  List<Map<String, dynamic>> comments = [];

  @override
  void initState() {
    super.initState();

    loadComments();
  }

  Future<void> loadComments() async {
    final data = await commentService.getComments(widget.postId);
    if (!mounted) return;
    setState(() {
      comments = data;
    });
  }

  Future<void> sendComment() async {
    if (controller.text.trim().isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    try {
      await commentService.addComment(
        postId: widget.postId,
        content: controller.text.trim(),
      );

      controller.clear();
      await loadComments();
      widget.onCommentAdded?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo publicar el comentario.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,

      decoration: const BoxDecoration(
        color: Color(0xff17131f),

        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),

      child: Column(
        children: [
          const SizedBox(height: 15),

          Container(
            width: 50,

            height: 5,

            decoration: BoxDecoration(
              color: Colors.white30,

              borderRadius: BorderRadius.circular(20),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            "Comentarios",

            style: TextStyle(
              color: Colors.white,

              fontSize: 20,

              fontWeight: FontWeight.bold,
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: comments.length,

              itemBuilder: (context, index) {
                final comment = comments[index];
                final profile = comment['profiles'] as Map<String, dynamic>?;
                final userId = comment['user_id']?.toString();
                final username =
                    profile?['username']?.toString() ??
                    comment['username']?.toString() ??
                    'Usuario';
                final avatarUrl = profile?['avatar_url']?.toString() ?? '';

                return ListTile(
                  onTap: userId == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          ProfileNavigationService.instance.openProfile(userId);
                        },
                  leading: _avatar(avatarUrl, username),
                  title: Text(
                    username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: MentionText(
                    text: comment['content']?.toString() ?? '',
                    style: const TextStyle(color: Colors.white70),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,

              left: 15,

              right: 15,
            ),

            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,

                    style: const TextStyle(color: Colors.white),

                    decoration: InputDecoration(
                      hintText: "Escribe un comentario...",

                      hintStyle: const TextStyle(color: Colors.white54),

                      filled: true,

                      fillColor: Colors.white10,

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),

                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                IconButton(
                  onPressed: sendComment,

                  icon: const Icon(Icons.send, color: Colors.deepPurple),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),
        ],
      ),
    );
  }

  Widget _avatar(String avatarUrl, String username) => CircleAvatar(
    backgroundColor: const Color(0xff6438FF),
    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
    child: avatarUrl.isEmpty
        ? Text(
            username.isEmpty ? '?' : username.characters.first.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          )
        : null,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
