import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../screens/full_video_screen.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String url;

  const VideoPlayerWidget({super.key, required this.url});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late final Player player;

  late final VideoController controller;

  bool loading = true;

  bool playing = false;

  bool showControls = true;

  bool seeking = false;

  double volume = 100;

  Timer? controlsTimer;

  Duration position = Duration.zero;

  Duration duration = Duration.zero;

  @override
  void initState() {
    super.initState();

    player = Player();

    controller = VideoController(player);

    player.stream.position.listen((value) {
      if (mounted && !seeking) {
        setState(() {
          position = value;
        });
      }
    });

    player.stream.duration.listen((value) {
      if (mounted) {
        setState(() {
          duration = value;
        });
      }
    });

    player.stream.volume.listen((value) {
      if (mounted) {
        setState(() {
          volume = value;
        });
      }
    });

    player.stream.completed.listen((_) {
      player.seek(Duration.zero);

      player.play();
    });

    loadVideo();
  }

  Future<void> loadVideo() async {
    await player.open(Media(widget.url), play: false);

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  void visibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction > 0.65) {
      if (!playing) {
        player.play();

        setState(() {
          playing = true;
        });
      }
    } else {
      player.pause();

      setState(() {
        playing = false;
      });
    }
  }

  void togglePlay() {
    if (playing) {
      player.pause();
    } else {
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

    return VisibilityDetector(
      key: Key(widget.url),

      onVisibilityChanged: visibilityChanged,

      child: MouseRegion(
        onEnter: (_) {
          showVideoControls();
        },

        onHover: (_) {},

        child: GestureDetector(
          onTap: showVideoControls,

          onDoubleTap: () {
            togglePlay();
          },

          child: Stack(
            alignment: Alignment.center,

            children: [
              Video(
                controller: controller,

                fit: BoxFit.contain,

                controls: NoVideoControls,
              ),

              if (loading) const CircularProgressIndicator(color: Colors.white),

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
                              volume == 0 ? Icons.volume_off : Icons.volume_up,

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
                              position = Duration(milliseconds: value.toInt());
                            });
                          },

                          onChangeEnd: (value) {
                            player.seek(Duration(milliseconds: value.toInt()));

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
    );
  }

  @override
  void dispose() {
    controlsTimer?.cancel();

    player.dispose();

    super.dispose();
  }
}
