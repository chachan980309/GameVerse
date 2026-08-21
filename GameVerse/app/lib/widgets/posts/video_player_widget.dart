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
  final String? thumbnailUrl;
  final String? duration;

  const VideoPlayerWidget({
    super.key,
    required this.url,
    required this.videoId,
    required this.videoController,
    this.thumbnailUrl,
    this.duration,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  Player? player;
  VideoController? controller;

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
  bool _isFullscreen = false;
  bool _videoReadyToRender = false;
  String? _openedUrl;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    widget.videoController.addListener(_onActiveVideoChanged);
    debugPrint(
      "[LOG-VIDEO] Widget creado. ID: ${widget.videoId}, URL: ${widget.url}",
    );
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      debugPrint("[LOG-VIDEO] URL ha cambiado. Forzando reinicio.");
      _destroyPlayer();
    }
  }

  void _onActiveVideoChanged() {
    if (!widget.videoController.isActive(widget.videoId) && playing) {
      debugPrint(
        "[LOG-VIDEO] Exclusividad: Otro video se reprodujo. Autodestruyendo...",
      );
      _destroyPlayer();
    }
  }

  Future<bool> _ensureOpened() async {
    if (_isOpening) return false;
    if (_openedUrl == widget.url && player != null) return true;
    _isOpening = true;

    debugPrint(
      "[LOG-VIDEO] Inicialización iniciada para el video: ${widget.videoId}",
    );
    debugPrint("[LOG-VIDEO] URL del video: ${widget.url}");

    if (mounted) setState(() => loading = true);
    try {
      final p = Player();
      player = p;

      controller = VideoController(p);

      // Suscribir eventos del reproductor dinámico
      _subscriptions.add(
        p.stream.position.listen((value) {
          if (mounted && !seeking) {
            setState(() {
              position = value;
              if (value > Duration.zero && !_videoReadyToRender && playing) {
                _videoReadyToRender = true;
                debugPrint(
                  "[LOG-VIDEO] Primer frame renderizado. readyToRender = true",
                );
              }
            });
          }
        }),
      );

      _subscriptions.add(
        p.stream.duration.listen((value) {
          if (mounted) {
            setState(() {
              duration = value;
            });
            debugPrint("[LOG-VIDEO] Duración cargada del video: $value");
          }
        }),
      );

      _subscriptions.add(
        p.stream.videoParams.listen((value) {
          final ratio = value.aspect;
          if (mounted && ratio != null && ratio > 0) {
            setState(() => videoAspectRatio = ratio);
            debugPrint(
              "[LOG-VIDEO] Parámetros de video cargados. Aspect Ratio: $ratio",
            );
          }
        }),
      );

      _subscriptions.add(
        p.stream.volume.listen((value) {
          if (mounted) {
            setState(() {
              volume = value;
            });
          }
        }),
      );

      _subscriptions.add(
        p.stream.completed.listen((completed) {
          if (!mounted || !widget.videoController.isActive(widget.videoId)) {
            return;
          }

          // Verificar de forma robusta si el video realmente ha finalizado
          final isAtEnd =
              p.state.position >= p.state.duration &&
              p.state.duration != Duration.zero;

          if (completed && isAtEnd) {
            debugPrint(
              "[LOG-VIDEO] Video completado REALMENTE. Posición: ${p.state.position}, Duración: ${p.state.duration}. Ejecutando limpieza...",
            );
            _destroyPlayer();
          } else {
            debugPrint(
              "[LOG-VIDEO] Ignorando evento completed transitorio. Posición actual: ${p.state.position}, Duración: ${p.state.duration}",
            );
          }
        }),
      );

      debugPrint("[LOG-VIDEO] Abriendo media en reproductor...");
      await p.open(Media(widget.url), play: false);
      _openedUrl = widget.url;
      _isOpened = true;

      // DIAGNÓSTICO INMEDIATO POST-INITIALIZE
      debugPrint("[LOG-VIDEO-DIAGNOSTIC] === POST-INITIALIZE STATES ===");
      debugPrint("  - p.state.duration: ${p.state.duration}");
      debugPrint("  - p.state.position: ${p.state.position}");
      debugPrint("  - isInitialized (Opened): $_isOpened");
      debugPrint("  - p.state.playing (isPlaying): ${p.state.playing}");
      debugPrint("  - p.state.completed (isCompleted): ${p.state.completed}");
      debugPrint("=================================================");

      return true;
    } catch (e) {
      debugPrint(
        "[LOG-VIDEO-ERROR] Excepción silenciosa capturada en inicialización: $e",
      );
      return false;
    } finally {
      _isOpening = false;
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _destroyPlayer({bool notify = true}) async {
    debugPrint("[LOG-VIDEO] Solicitando Dispose/Destroy de reproductor...");
    controlsTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    final p = player;
    player = null;
    controller = null;
    _isOpened = false;
    playing = false;
    _videoReadyToRender = false;
    _openedUrl = null;

    if (notify && mounted) {
      setState(() {});
    }

    if (p != null) {
      await p.dispose();
      debugPrint(
        "[LOG-VIDEO] Dispose/Destroy completado (reproductor liberado).",
      );
    }
  }

  void visibilityChanged(VisibilityInfo info) async {
    final fraction = info.visibleFraction;
    debugPrint(
      "[LOG-VIDEO] VisibilityChanged: Fracción Visible = $fraction, Playing = $playing, Opened = $_isOpened",
    );

    // Si sale completamente de pantalla (0.0 visible), destruir para liberar recursos
    // Se usa fraction == 0.0 para evitar detener el video por falsos positivos de fracciones intermedias durante rebuilds
    if (!_isFullscreen && fraction == 0.0 && (playing || _isOpened)) {
      debugPrint(
        "[LOG-VIDEO] Video salió completamente de la pantalla. Autodestruyendo...",
      );
      await _destroyPlayer();
    }
  }

  Future<void> togglePlay() async {
    try {
      if (playing && player != null) {
        debugPrint("[LOG-VIDEO] Solicitando Pause...");
        player!.pause();
        setState(() {
          playing = false;
        });
        debugPrint("[LOG-VIDEO] Pause ejecutado");
      } else {
        debugPrint("[LOG-VIDEO] Solicitando Play...");
        if (!await _ensureOpened()) {
          debugPrint(
            "[LOG-VIDEO-ERROR] No se pudo inicializar el reproductor.",
          );
          return;
        }
        widget.videoController.setActiveVideo(widget.videoId);
        player!.play();
        setState(() {
          playing = true;
          _videoReadyToRender = true;
        });
        debugPrint("[LOG-VIDEO] Play ejecutado");
      }
    } catch (e) {
      debugPrint("[LOG-VIDEO-ERROR] Excepción capturada en togglePlay: $e");
    }
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
    player?.setVolume(value);
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

  Future<void> goFullscreen() async {
    if (player == null || controller == null) return;

    // VisibilityDetector reports 0% while the fullscreen route covers this
    // widget. Keep the shared player alive until that route closes.
    setState(() => _isFullscreen = true);
    controlsTimer?.cancel();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FullVideoScreen(player: player!, controller: controller!),
      ),
    );

    if (!mounted) return;
    if (player == null) {
      setState(() => _isFullscreen = false);
      return;
    }
    setState(() {
      _isFullscreen = false;
      playing = player!.state.playing;
      position = player!.state.position;
      duration = player!.state.duration;
      _videoReadyToRender = true;
    });
    showVideoControls();
  }

  Widget _buildThumbnail() {
    final hasThumbnail =
        widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Miniatura JPEG real
        hasThumbnail
            ? Image.network(
                widget.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildProceduralPlaceholder(),
              )
            : _buildProceduralPlaceholder(),

        // Vignette oscura
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0x99000000), Colors.transparent],
            ),
          ),
        ),

        // Botón Play centrado gigante
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x3F000000),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
        ),

        // Esquina inferior derecha: Duración
        if (widget.duration != null && widget.duration!.isNotEmpty)
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xBD000000),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.duration!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProceduralPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff1f1338), Color(0xff120e22), Color(0xff090712)],
        ),
      ),
      child: const Center(
        child: Opacity(
          opacity: 0.15,
          child: Icon(
            Icons.sports_esports_rounded,
            color: Colors.white,
            size: 80,
          ),
        ),
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
                onEnter: (_) {
                  if (_videoReadyToRender) showVideoControls();
                },
                child: GestureDetector(
                  onTap: togglePlay,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Capa 1: Miniatura Jpeg Real (Se muestra siempre que no esté reproduciendo)
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: _videoReadyToRender,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: _videoReadyToRender ? 0.0 : 1.0,
                            child: _buildThumbnail(),
                          ),
                        ),
                      ),

                      // Capa 2: Reproductor de Video (Se crea y renderiza SOLO bajo demanda y cuando está listo)
                      if (!_isFullscreen &&
                          _isOpened &&
                          controller != null &&
                          _videoReadyToRender)
                        Positioned.fill(
                          child: Video(
                            controller: controller!,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            controls: NoVideoControls,
                          ),
                        ),

                      if (loading)
                        const CircularProgressIndicator(color: Colors.white),

                      if (showControls && _videoReadyToRender)
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
                                    player?.seek(
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
    widget.videoController.removeListener(_onActiveVideoChanged);
    _destroyPlayer(notify: false);
    debugPrint("[LOG-VIDEO] Widget destruido (dispose) ID: ${widget.videoId}");
    super.dispose();
  }
}
