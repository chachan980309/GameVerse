import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class FullVideoScreen extends StatefulWidget {
  const FullVideoScreen({
    super.key,
    required this.player,
    required this.controller,
  });

  final Player player;
  final VideoController controller;

  @override
  State<FullVideoScreen> createState() => _FullVideoScreenState();
}

class _FullVideoScreenState extends State<FullVideoScreen> {
  final FocusNode _focusNode = FocusNode();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _controlsTimer;

  late bool _playing;
  bool _showControls = true;
  bool _seeking = false;
  late Duration _position;
  late Duration _duration;
  late double _volume;

  @override
  void initState() {
    super.initState();
    _playing = widget.player.state.playing;
    _position = widget.player.state.position;
    _duration = widget.player.state.duration;
    _volume = widget.player.state.volume;

    _subscriptions.add(
      widget.player.stream.playing.listen((value) {
        if (mounted) setState(() => _playing = value);
      }),
    );
    _subscriptions.add(
      widget.player.stream.position.listen((value) {
        if (mounted && !_seeking) setState(() => _position = value);
      }),
    );
    _subscriptions.add(
      widget.player.stream.duration.listen((value) {
        if (mounted) setState(() => _duration = value);
      }),
    );
    _subscriptions.add(
      widget.player.stream.volume.listen((value) {
        if (mounted) setState(() => _volume = value);
      }),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _scheduleControlsHide();
    });
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _togglePlay() {
    _playing ? widget.player.pause() : widget.player.play();
    _showControlsTemporarily();
  }

  void _showControlsTemporarily() {
    if (mounted) setState(() => _showControls = true);
    _scheduleControlsHide();
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    if (!_playing) return;
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _close() => Navigator.of(context).pop();

  String _formatTime(Duration value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);
    return hours > 0
        ? '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}'
        : '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final maxPosition = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds.toDouble()
        : 1.0;
    final currentPosition = _position.inMilliseconds
        .clamp(0, maxPosition.toInt())
        .toDouble();

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        if (event.logicalKey == LogicalKeyboardKey.escape) _close();
        if (event.logicalKey == LogicalKeyboardKey.space) _togglePlay();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MouseRegion(
          onHover: (_) => _showControlsTemporarily(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlay,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Video(
                  controller: widget.controller,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  controls: NoVideoControls,
                ),
                AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 18,
                          left: 18,
                          child: SafeArea(
                            child: IconButton.filledTonal(
                              tooltip: 'Salir de pantalla completa (Esc)',
                              onPressed: _close,
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                          ),
                        ),
                        Center(
                          child: Icon(
                            _playing
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            color: Colors.white.withValues(alpha: 0.92),
                            size: 72,
                          ),
                        ),
                        Positioned(
                          left: 24,
                          right: 24,
                          bottom: 18,
                          child: SafeArea(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: _togglePlay,
                                    icon: Icon(
                                      _playing
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '${_formatTime(_position)} / ${_formatTime(_duration)}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Slider(
                                      value: currentPosition,
                                      max: maxPosition,
                                      onChangeStart: (_) => _seeking = true,
                                      onChanged: (value) => setState(() {
                                        _position = Duration(
                                          milliseconds: value.toInt(),
                                        );
                                      }),
                                      onChangeEnd: (value) {
                                        _seeking = false;
                                        widget.player.seek(
                                          Duration(milliseconds: value.toInt()),
                                        );
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: _volume == 0
                                        ? 'Activar sonido'
                                        : 'Silenciar',
                                    onPressed: () => widget.player.setVolume(
                                      _volume == 0 ? 100 : 0,
                                    ),
                                    icon: Icon(
                                      _volume == 0
                                          ? Icons.volume_off_rounded
                                          : Icons.volume_up_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Salir de pantalla completa',
                                    onPressed: _close,
                                    icon: const Icon(
                                      Icons.fullscreen_exit_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
      ),
    );
  }
}
