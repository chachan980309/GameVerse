import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';

import '../controllers/post_controller.dart';
import '../services/post_navigation_service.dart';
import '../widgets/forms/create_post.dart';
import '../widgets/posts/post_list.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final PostController postController = PostController.instance;
  final ScrollController _feedScrollController = ScrollController();
  int _selectedFeed = 0;

  @override
  void initState() {
    super.initState();
    PostNavigationService.instance.addListener(_onPostRequested);
  }

  @override
  void dispose() {
    PostNavigationService.instance.removeListener(_onPostRequested);
    _feedScrollController.dispose();
    super.dispose();
  }

  void _onPostRequested() {
    if (mounted) setState(() {});
  }

  void _scrollFeed(double delta) {
    if (!_feedScrollController.hasClients) return;

    final position = _feedScrollController.position;
    final target = (position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    if (target != position.pixels) {
      _feedScrollController.jumpTo(target);
    }
  }

  Widget _scrollSide() => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerSignal: (event) {
      if (event is PointerScrollEvent) {
        _scrollFeed(event.scrollDelta.dy);
      }
    },
    child: const SizedBox.expand(),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // La tarjeta individual mide 820 px. Se añaden 28 px para el padding
      // propio del feed, manteniendo la misma proporción visual.
      final feedWidth = constraints.maxWidth > 900
          ? 848.0
          : constraints.maxWidth;

      final hasLateralSpace = constraints.maxWidth > 900;

      return SizedBox(
        width: double.infinity,
        height: constraints.maxHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Scrollbar(
              controller: _feedScrollController,
              thumbVisibility: hasLateralSpace,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasLateralSpace) Expanded(child: _scrollSide()),
                  SizedBox(
                    width: feedWidth,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                      child: Column(
                        children: [
                          CreatePost(onPostCreated: postController.loadFeed),
                          const SizedBox(height: 12),
                          _feedTabs(),
                          const SizedBox(height: 12),
                          Expanded(
                            child: AnimatedBuilder(
                              animation: postController,
                              builder: (context, _) => ScrollConfiguration(
                                behavior: ScrollConfiguration.of(
                                  context,
                                ).copyWith(scrollbars: false),
                                child: PostList(
                                  posts: postController.feedPosts,
                                  loading: postController.isLoading,
                                  onRefresh: postController.loadFeed,
                                  emptyMessage: 'Aún no hay publicaciones.',
                                  focusPostId:
                                      PostNavigationService.instance.postId,
                                  scrollController: _feedScrollController,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (hasLateralSpace) Expanded(child: _scrollSide()),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _feedTabs() => Container(
    height: 50,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF171625),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF2E2A40)),
    ),
    child: Row(
      children: [
        _tab('Para ti', 0),
        _tab('Siguiendo', 1),
        _tab('Populares', 2),
        const Spacer(),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.tune_rounded, size: 17),
          label: const Text('Filtrar'),
          style: TextButton.styleFrom(foregroundColor: Colors.white54),
        ),
      ],
    ),
  );

  Widget _tab(String label, int index) {
    final selected = _selectedFeed == index;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _selectedFeed = index),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          border: selected
              ? const Border(
                  bottom: BorderSide(color: Color(0xFF8B5CF6), width: 3),
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFC5B4FF) : Colors.white60,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
