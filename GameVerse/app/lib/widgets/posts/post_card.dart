import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../controllers/video_feed_controller.dart';
import '../../models/post_model.dart';
import '../../pages/live_stream_page.dart';
import '../../services/live_stream_service.dart';

import 'post_actions.dart';
import 'post_header.dart';
import 'post_media.dart';
import '../mention_text.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final int index;
  final VideoFeedController videoController;

  const PostCard({
    super.key,
    required this.post,
    required this.index,
    required this.videoController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER
          PostHeader(post: post),

          /// CONTENIDO
          // En un compartido, el contenido real vive exclusivamente dentro de
          // la tarjeta original para mantener ambas publicaciones separadas.
          if (post.content.isNotEmpty && !post.isSharedPost) ...[
            const SizedBox(height: 16),
            MentionText(
              text: post.content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],

          // El compartido se presenta como una publicación independiente,
          // no mezclado con la publicación de quien la compartió.
          if (post.sharedPost != null) ...[
            const SizedBox(height: 14),
            _SharedPostCard(
              post: post.sharedPost!,
              index: index,
              videoController: videoController,
            ),
          ],

          // Old shares did not retain the original post id. Keep their text
          // separated visually instead of repeating it in the outer post.
          if (post.isSharedPost && post.sharedPost == null) ...[
            const SizedBox(height: 14),
            _LegacySharedPostCard(content: post.content),
          ],

          /// DIRECTO
          if (post.type == 'live' && post.streamId != null) ...[
            const SizedBox(height: 14),
            _LivePostBanner(post: post),
          ],

          /// MEDIA
          if (post.type != 'live' &&
              ((post.imageUrl != null && post.imageUrl!.isNotEmpty) ||
                  (post.videoUrl != null && post.videoUrl!.isNotEmpty))) ...[
            const SizedBox(height: 16),
            PostMedia(
              post: post,
              index: index,
              videoController: videoController,
            ),
          ],

          const SizedBox(height: 16),

          /// ACCIONES
          PostActions(post: post),
        ],
      ),
    );
  }
}

class _LivePostBanner extends StatefulWidget {
  const _LivePostBanner({required this.post});
  final PostModel post;

  @override
  State<_LivePostBanner> createState() => _LivePostBannerState();
}

class _LivePostBannerState extends State<_LivePostBanner> {
  final LiveStreamService _liveService = LiveStreamService();
  Room? _room;
  VideoTrack? _screenTrack;
  bool _connecting = true;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _connectIfVisible();
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  Future<void> _connectIfVisible() async {
    if (!_isVisible) return;
    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      if (session == null) return;

      final stream = await _liveService.getActiveStream(widget.post.streamId!);
      if (stream == null) {
        if (mounted) setState(() => _connecting = false);
        return;
      }

      final roomName = stream['room_name']?.toString() ?? '';
      final response = await supabase.functions.invoke(
        'livekit-token',
        body: {'room': roomName, 'roomType': 'live'},
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final token = data['token']?.toString() ?? '';
      final url = data['url']?.toString() ?? '';

      if (token.split('.').length != 3) return;

      final room = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );
      _room = room;

      room.addListener(_onRoomChanged);
      await room.prepareConnection(url, token);
      await room.connect(url, token);

      if (mounted) setState(() => _connecting = false);
    } catch (_) {
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _onRoomChanged() {
    if (!mounted) return;
    VideoTrack? found;
    for (final p in (_room?.remoteParticipants.values ?? <RemoteParticipant>[])) {
      final pubs = p.videoTrackPublications;
      for (final pub in List.of(pubs)) {
        final track = pub.track;
        if (track is VideoTrack && !pub.muted) {
          found = track;
          break;
        }
      }
      if (found != null) break;
    }
    if (mounted) setState(() => _screenTrack = found);
  }

  Future<void> _disconnect() async {
    _room?.removeListener(_onRoomChanged);
    await _room?.disconnect();
    await _room?.dispose();
    _room = null;
  }

  void _openFullscreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveStreamPage(
          streamId: widget.post.streamId!,
          roomName: '',
          title: widget.post.content,
          isHost: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('live-${widget.post.streamId}'),
      onVisibilityChanged: (info) {
        final isVisible = info.visibleFraction > 0.5;
        if (isVisible != _isVisible) {
          _isVisible = isVisible;
          if (isVisible) {
            _connectIfVisible();
          } else {
            _disconnect();
          }
        }
      },
      child: GestureDetector(
        onTap: () => _openFullscreen(context),
        child: Container(
          width: double.infinity,
          height: 250,
          decoration: BoxDecoration(
            color: const Color(0xff08070C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffD9485F), width: 1.5),
          ),
          child: Stack(
            children: [
              if (_screenTrack != null && !_connecting)
                VideoTrackRenderer(_screenTrack!)
              else
                Container(
                  color: const Color(0xff0F0D19),
                  child: Center(
                    child: _connecting
                        ? const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xff8B4DFF),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Conectando...',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          )
                        : const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.screen_share_rounded,
                                color: Color(0xffD9485F),
                                size: 60,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Transmisión en directo',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xffD9485F),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Colors.white, size: 8),
                      SizedBox(width: 5),
                      Text(
                        'EN DIRECTO',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.post.content,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.post.username} está transmitiendo',
                              style: const TextStyle(
                                color: Color(0xffC8A0E8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () => _openFullscreen(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xffD9485F),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        icon: const Icon(Icons.fullscreen_rounded, size: 16),
                        label: const Text(
                          'Pantalla completa',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegacySharedPostCard extends StatelessWidget {
  const _LegacySharedPostCard({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFF151321),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF6237B8)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.article_outlined, color: Color(0xFF9A78FF)),
        const SizedBox(width: 10),
        Expanded(
          child: MentionText(
            text: content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SharedPostCard extends StatelessWidget {
  const _SharedPostCard({
    required this.post,
    required this.index,
    required this.videoController,
  });

  final PostModel post;
  final int index;
  final VideoFeedController videoController;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFF151321),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF6237B8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PostHeader(post: post),
        if (post.content.isNotEmpty) ...[
          const SizedBox(height: 12),
          MentionText(
            text: post.content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
        if ((post.imageUrl?.isNotEmpty ?? false) ||
            (post.videoUrl?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: PostMedia(
              post: post,
              index: index,
              videoController: videoController,
            ),
          ),
        ],
      ],
    ),
  );
}
