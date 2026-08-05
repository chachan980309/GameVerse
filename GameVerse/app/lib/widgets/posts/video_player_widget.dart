import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../screens/full_video_screen.dart';
import '../../controllers/video_feed_controller.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  final String videoId;
  final VideoFeedController videoController;

  const VideoPlayerWidget({
    super.key,
    required this.url,
    required this.videoId,
    required this.videoController,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late final Player player;

  late final VideoController controller;

  bool loading = false;

  bool playing = false;

  bool showControls = true;

  bool seeking = false;

  double volume = 100;

  Timer? controlsTimer;

  Duration position = Duration.zero;

  Duration duration = Duration.zero;

  double? videoAspectRatio;
  bool _isOpened = false;
  bool _isOpening = false;
  String? _openedUrl;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  void initState() {
    super.initState();

    player = Player();

    controller = VideoController(player);

    _subscriptions.add(
      player.stream.position.listen((value) {
        if (mounted && !seeking) {
          setState(() {
            position = value;
          });
        }
      }),
    );

    _subscriptions.add(
      player.stream.duration.listen((value) {
        if (mounted) {
          setState(() {
            duration = value;
          });
        }
      }),
    );

    _subscriptions.add(
      player.stream.videoParams.listen((value) {
        final ratio = value.aspect;
        if (mounted && ratio != null && ratio > 0) {
          setState(() => videoAspectRatio = ratio);
        }
      }),
    );

    _subscriptions.add(
      player.stream.volume.listen((value) {
        if (mounted) {
          setState(() {
            volume = value;
          });
        }
      }),
    );

    _subscriptions.add(
      player.stream.completed.listen((_) {
        if (!mounted || !widget.videoController.isActive(widget.videoId))
          return;
        player.pause();
        player.seek(Duration.zero);
        setState(() => playing = false);
      }),
    );
    widget.videoController.addListener(_onActiveVideoChanged);
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      player.pause();
      _openedUrl = null;
      _isOpened = false;
      playing = false;
    }
  }

  void _onActiveVideoChanged() {
    if (!widget.videoController.isActive(widget.videoId) && playing) {
      player.pause();
      if (mounted) setState(() => playing = false);
    }
  }

  Future<bool> _ensureOpened() async {
    if (_isOpening) return false;
    if (_openedUrl == widget.url) return true;
    _isOpening = true;
    if (mounted) setState(() => loading = true);
    try {
      await player.open(Media(widget.url), play: false);
      _openedUrl = widget.url;
      _isOpened = true;
      return true;
    } catch (_) {
      return false;
    } finally {
      _isOpening = false;
      if (mounted) setState(() => loading = false);
    }
  }

  void visibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction <= 0.3 && playing) {
      player.pause();
      setState(() {
        playing = false;
      });
    }
  }

  Future<void> togglePlay() async {
    if (playing) {
      player.pause();
    } else {
      if (!await _ensureOpened()) return;
      widget.videoController.setActiveVideo(widget.videoId);
      player.play();
    }

    setState(() {
      playing = !playing;
    });

    showVideoControls();
  }

  void showVideoControls() {
    if (!mounted) return;

    setState(() {
      showControls = true;
    });

    controlsTimer?.cancel();

    controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          showControls = false;
        });
      }
    });
  }

  void changeVolume(double value) {
    setState(() {
      volume = value;
    });

    player.setVolume(value);
  }

  void toggleMute() {
    if (volume == 0) {
      changeVolume(100);
    } else {
      changeVolume(0);
    }
  }

  String formatTime(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');

    return "${two(d.inMinutes)}:${two(d.inSeconds % 60)}";
  }

  void goFullscreen() {
    Navigator.push(
      context,

      MaterialPageRoute(
        builder: (_) => FullVideoScreen(player: player, controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double maxValue = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : 1;

    double currentValue = position.inMilliseconds
        .clamp(0, maxValue.toInt())
        .toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = videoAspectRatio ?? (16 / 9);
        // Los videos verticales quedan compactos, y los horizontales ocupan
        // el ancho disponible sin forzar grandes bandas negras laterales.
        final maxHeight = ratio < 0.9 ? 520.0 : 420.0;
        final width = math.min(constraints.maxWidth, maxHeight * ratio);
        final height = width / ratio;

        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: VisibilityDetector(
              key: ValueKey('video-visibility-${widget.videoId}'),
              onVisibilityChanged: visibilityChanged,
              child: MouseRegion(
                onEnter: (_) => showVideoControls(),
                child: GestureDetector(
                  onTap: showVideoControls,
                  onDoubleTap: togglePlay,
                  child: Stack(
                    alignment: Alignment.center,

                    children: [
                      if (_isOpened)
                        Video(
                          controller: controller,
                          fit: BoxFit.contain,
                          controls: NoVideoControls,
                        )
                      else
                        const DecoratedBox(
                          decoration: BoxDecoration(color: Color(0xff100E17)),
                          child: Center(
                            child: Icon(
                              Icons.play_circle_outline_rounded,
                              color: Colors.white54,
                              size: 54,
                            ),
                          ),
                        ),

                      if (loading)
                        const CircularProgressIndicator(color: Colors.white),

                      if (showControls)
                        Positioned(
                          left: 10,

                          right: 10,

                          bottom: 5,

                          child: Column(
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      playing ? Icons.pause : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 25,
                                    ),
                                    onPressed: togglePlay,
                                  ),

                                  Text(
                                    "${formatTime(position)} / ${formatTime(duration)}",

                                    style: const TextStyle(
                                      color: Colors.white,

                                      fontSize: 12,
                                    ),
                                  ),

                                  const Spacer(),

                                  IconButton(
                                    icon: Icon(
                                      volume == 0
                                          ? Icons.volume_off
                                          : Icons.volume_up,

                                      color: Colors.white,
                                    ),

                                    onPressed: toggleMute,
                                  ),

                                  SizedBox(
                                    width: 120,

                                    child: Slider(
                                      value: volume,

                                      min: 0,

                                      max: 100,

                                      onChanged: changeVolume,

                                      activeColor: const Color(0xff8B5CFF),

                                      inactiveColor: Colors.white24,
                                    ),
                                  ),

                                  IconButton(
                                    icon: const Icon(
                                      Icons.fullscreen,

                                      color: Colors.white,
                                    ),

                                    onPressed: goFullscreen,
                                  ),
                                ],
                              ),

                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 7,

                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8,
                                  ),

                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 14,
                                  ),

                                  activeTrackColor: const Color(0xff8B5CFF),

                                  inactiveTrackColor: Colors.white24,

                                  thumbColor: const Color(0xff8B5CFF),
                                ),

                                child: Slider(
                                  value: currentValue,

                                  max: maxValue,

                                  onChangeStart: (_) {
                                    seeking = true;
                                  },

                                  onChanged: (value) {
                                    setState(() {
                                      position = Duration(
                                        milliseconds: value.toInt(),
                                      );
                                    });
                                  },

                                  onChangeEnd: (value) {
                                    player.seek(
                                      Duration(milliseconds: value.toInt()),
                                    );

                                    seeking = false;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    controlsTimer?.cancel();
    widget.videoController.removeListener(_onActiveVideoChanged);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }

    player.dispose();

    super.dispose();
  }
}
