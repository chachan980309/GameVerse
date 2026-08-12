import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Respaldo para escritorio y móvil. En web se usa el elemento de video
/// nativo del navegador, que realiza un loop sin el flash del renderer.
class ClanHeroVideoBackground extends StatefulWidget {
  const ClanHeroVideoBackground({super.key, required this.url});

  final String url;

  @override
  State<ClanHeroVideoBackground> createState() =>
      _ClanHeroVideoBackgroundState();
}

class _ClanHeroVideoBackgroundState extends State<ClanHeroVideoBackground> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _open(widget.url);
  }

  Future<void> _open(String url) async {
    await _player.setVolume(0);
    await _player.setPlaylistMode(PlaylistMode.loop);
    await _player.open(Media(url), play: true);
  }

  @override
  void didUpdateWidget(covariant ClanHeroVideoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _open(widget.url);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Video(
      controller: _controller,
      controls: NoVideoControls,
      fit: BoxFit.cover,
    ),
  );
}
