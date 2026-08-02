import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/post_model.dart';
import '../services/comment_service.dart';
import '../widgets/posts/post_actions.dart';

class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({
    super.key,
    required this.imageUrl,
    this.post,
  });

  final String imageUrl;
  final PostModel? post;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF09080D),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sidebar = post == null ? null : _PhotoSidebar(post: post);
              final image = _ImageStage(imageUrl: widget.imageUrl);
              final close = IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
              );

              if (sidebar == null) {
                return Stack(children: [Positioned.fill(child: image), Positioned(top: 8, right: 12, child: close)]);
              }

              if (constraints.maxWidth >= 900) {
                return Row(
                  children: [
                    Expanded(child: Stack(children: [Positioned.fill(child: image), Positioned(top: 8, right: 12, child: close)])),
                    SizedBox(width: 360, child: sidebar),
                  ],
                );
              }

              return Column(
                children: [
                  Expanded(child: Stack(children: [Positioned.fill(child: image), Positioned(top: 8, right: 12, child: close)])),
                  SizedBox(height: 290, child: sidebar),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ImageStage extends StatelessWidget {
  const _ImageStage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            panEnabled: true,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  width: 46,
                  height: 46,
                  child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                );
              },
              errorBuilder: (_, _, _) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 52,
              ),
            ),
          ),
        ),
      );
}

class _PhotoSidebar extends StatefulWidget {
  const _PhotoSidebar({required this.post});

  final PostModel post;

  @override
  State<_PhotoSidebar> createState() => _PhotoSidebarState();
}

class _PhotoSidebarState extends State<_PhotoSidebar> {
  final CommentService _comments = CommentService();
  late Future<List<Map<String, dynamic>>> _commentFuture = _loadComments();

  Future<List<Map<String, dynamic>>> _loadComments() => _comments.getComments(widget.post.id);

  void _refreshComments() {
    setState(() => _commentFuture = _loadComments());
  }

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF17141F),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF30274B),
                  backgroundImage: widget.post.avatarUrl.isEmpty
                      ? null
                      : NetworkImage(widget.post.avatarUrl),
                  child: widget.post.avatarUrl.isEmpty
                      ? Text(widget.post.username.characters.first.toUpperCase())
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.post.username,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (widget.post.content.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(widget.post.content, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
            ],
            const SizedBox(height: 8),
            PostActions(post: widget.post, onCommentChanged: _refreshComments),
            const Divider(color: Colors.white12),
            Row(
              children: [
                const Expanded(child: Text('Comentarios', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                IconButton(
                  tooltip: 'Actualizar comentarios',
                  onPressed: _refreshComments,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 19),
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _commentFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  final comments = snapshot.data ?? [];
                  if (comments.isEmpty) {
                    return const Center(child: Text('Aún no hay comentarios.', style: TextStyle(color: Colors.white54)));
                  }
                  return ListView.separated(
                    itemCount: comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      final profile = comment['profiles'] as Map<String, dynamic>?;
                      final name = profile?['username']?.toString() ?? comment['username']?.toString() ?? 'Usuario';
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: const Color(0xFF30274B),
                            backgroundImage: (profile?['avatar_url']?.toString().isNotEmpty ?? false)
                                ? NetworkImage(profile!['avatar_url'].toString())
                                : null,
                            child: (profile?['avatar_url']?.toString().isNotEmpty ?? false)
                                ? null
                                : Text(name.characters.first.toUpperCase(), style: const TextStyle(fontSize: 11)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                                const SizedBox(height: 2),
                                Text(comment['content']?.toString() ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
}
