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
    if (postController.feedScope != FeedScope.all) {
      postController.loadFeed(scope: FeedScope.all);
    }
    PostNavigationService.instance.addListener(_onPostRequested);
    _feedScrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    PostNavigationService.instance.removeListener(_onPostRequested);
    _feedScrollController.removeListener(_onScroll);
    _feedScrollController.dispose();
    super.dispose();
  }

  void _onPostRequested() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_feedScrollController.hasClients) return;
    final threshold = _feedScrollController.position.maxScrollExtent - 200;
    if (_feedScrollController.position.pixels >= threshold) {
      postController.loadMoreFeed();
    }
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
                          CreatePost(
                            onPostCreated: () => postController.loadFeed(
                              scope: _selectedFeed == 0
                                  ? FeedScope.all
                                  : FeedScope.friends,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _feedTabs(),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(
                                context,
                              ).copyWith(scrollbars: false),
                              child: AnimatedBuilder(
                                animation: postController,
                                builder: (context, _) => PostList(
                                  posts: postController.feedPosts,
                                  loading: postController.isLoading,
                                  onRefresh: () => postController.loadFeed(
                                    scope: _selectedFeed == 0
                                        ? FeedScope.all
                                        : FeedScope.friends,
                                  ),
                                  emptyMessage: _selectedFeed == 0
                                      ? 'Aún no hay publicaciones.'
                                      : 'Tus amigos aún no han publicado.',
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
    height: 54,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF171526),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF2C2941), width: 1.2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x18000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
        BoxShadow(
          color: Color(0x067B4DFF),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [_tab('Feed', 0), const SizedBox(width: 6), _tab('Amigos', 1)],
    ),
  );

  Widget _tab(String label, int index) {
    final selected = _selectedFeed == index;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _selectFeed(index),
      child: Container(
        height: 38,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF7B4DFF).withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(
                  color: const Color(0xFF7B4DFF).withOpacity(0.24),
                  width: 1.2,
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFC5B4FF) : Colors.white60,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Future<void> _selectFeed(int index) async {
    if (_selectedFeed == index &&
        postController.feedScope ==
            (index == 0 ? FeedScope.all : FeedScope.friends)) {
      return;
    }
    setState(() => _selectedFeed = index);
    if (_feedScrollController.hasClients) {
      _feedScrollController.jumpTo(0);
    }
    await postController.loadFeed(
      scope: index == 0 ? FeedScope.all : FeedScope.friends,
    );
  }
}
