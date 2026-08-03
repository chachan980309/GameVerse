import 'package:flutter/material.dart';

import '../controllers/video_feed_controller.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../widgets/posts/post_card.dart';

/// Pantalla individual para abrir una publicación desde un chat, una
/// notificación o cualquier enlace interno. Mantiene el contexto de origen
/// al volver atrás en vez de enviar al usuario al feed completo.
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.postId});

  final String postId;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final PostService _postService = PostService();
  final VideoFeedController _videoController = VideoFeedController();
  late Future<PostModel?> _postFuture;

  @override
  void initState() {
    super.initState();
    _postFuture = _postService.getPostById(widget.postId);
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _postFuture = _postService.getPostById(widget.postId));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF12101A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF171421),
      elevation: 0,
      title: const Text(
        'Publicación',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: FutureBuilder<PostModel?>(
      future: _postFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF7B42F6)),
          );
        }

        if (snapshot.hasError) {
          return _StateMessage(
            icon: Icons.error_outline_rounded,
            message: 'No pudimos abrir esta publicación.',
            actionLabel: 'Reintentar',
            onAction: _reload,
          );
        }

        final post = snapshot.data;
        if (post == null) {
          return const _StateMessage(
            icon: Icons.article_outlined,
            message: 'Esta publicación ya no está disponible.',
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth > 900 ? 820 : double.infinity,
                ),
                child: PostCard(
                  post: post,
                  index: 0,
                  videoController: _videoController,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF9B79FF), size: 42),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
