import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

/// En Chrome el elemento HTMLVideoElement hace el loop en el mismo decoder,
/// sin limpiar el frame al final como puede ocurrir con un canvas externo.
class ClanHeroVideoBackground extends StatefulWidget {
  const ClanHeroVideoBackground({super.key, required this.url});

  final String url;

  @override
  State<ClanHeroVideoBackground> createState() =>
      _ClanHeroVideoBackgroundState();
}

class _ClanHeroVideoBackgroundState extends State<ClanHeroVideoBackground> {
  late final String _viewType;
  late final html.VideoElement _video;

  @override
  void initState() {
    super.initState();
    _viewType = 'nubzzz-clan-hero-video-${DateTime.now().microsecondsSinceEpoch}';
    _video = html.VideoElement()
      ..src = widget.url
      ..autoplay = true
      ..loop = true
      ..muted = true
      ..controls = false
      ..preload = 'auto'
      ..setAttribute('playsinline', '')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.backgroundColor = 'transparent';
    _video.onCanPlay.first.then((_) => _video.play());
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) => _video);
  }

  @override
  void didUpdateWidget(covariant ClanHeroVideoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _video
        ..src = widget.url
        ..load();
      _video.play();
    }
  }

  @override
  void dispose() {
    _video
      ..pause()
      ..removeAttribute('src')
      ..load();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: HtmlElementView(viewType: _viewType),
  );
}
