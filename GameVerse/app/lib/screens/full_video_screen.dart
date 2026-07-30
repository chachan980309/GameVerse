import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class FullVideoScreen extends StatefulWidget {
  final Player player;

  final VideoController controller;

  const FullVideoScreen({
    super.key,

    required this.player,

    required this.controller,
  });

  @override
  State<FullVideoScreen> createState() => _FullVideoScreenState();
}

class _FullVideoScreenState extends State<FullVideoScreen> {
  bool playing = true;

  @override
  void initState() {
    super.initState();

    widget.player.stream.playing.listen((value) {
      if (mounted) {
        setState(() {
          playing = value;
        });
      }
    });
  }

  void togglePlay() {
    if (playing) {
      widget.player.pause();
    } else {
      widget.player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: Stack(
        alignment: Alignment.center,

        children: [
          Center(
            child: Video(
              controller: widget.controller,

              fit: BoxFit.contain,

              controls: NoVideoControls,
            ),
          ),

          GestureDetector(
            onTap: togglePlay,

            child: Icon(
              playing ? Icons.pause_circle : Icons.play_circle,

              color: Colors.white,

              size: 80,
            ),
          ),

          Positioned(
            top: 30,

            left: 15,

            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 35),

              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
