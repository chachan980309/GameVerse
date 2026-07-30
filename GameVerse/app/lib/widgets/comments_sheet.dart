import 'package:flutter/material.dart';
import '../services/comment_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;

  const CommentsSheet({super.key, required this.postId});

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

    setState(() {
      comments = data;
    });
  }

  Future<void> sendComment() async {
    if (controller.text.trim().isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    final profile = await Supabase.instance.client
        .from('profiles')
        .select('username')
        .eq('id', user.id)
        .maybeSingle();

    final username = profile?['username'] ?? 'Usuario';

    try {
      await commentService.addComment(
        postId: widget.postId,
        username: username,
        content: controller.text.trim(),
      );

      controller.clear();
      loadComments();
    } catch (e) {
      print("ERROR COMENTARIO: $e");
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

                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.deepPurple,
                  ),

                  title: Text(
                    comment['username'] ?? '',

                    style: const TextStyle(
                      color: Colors.white,

                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  subtitle: Text(
                    comment['content'] ?? '',

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
}
