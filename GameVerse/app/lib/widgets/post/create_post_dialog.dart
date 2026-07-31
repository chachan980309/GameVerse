import 'package:flutter/material.dart';

import '../forms/create_post.dart';

class CreatePostDialog extends StatelessWidget {
  const CreatePostDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xff211D2E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: CreatePost(
            onPostCreated: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }
}
