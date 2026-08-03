import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';

/// Fondo reutilizable del feed cargado desde Supabase Storage.
///
/// El bucket debe ser público porque se obtiene una URL pública del archivo.
class FeedBackground extends StatefulWidget {
  const FeedBackground({
    super.key,
    this.bucketId = 'app-assets',
    this.objectPath = 'feed/default-background.png',
  });

  final String bucketId;
  final String objectPath;

  @override
  State<FeedBackground> createState() => _FeedBackgroundState();
}

class _FeedBackgroundState extends State<FeedBackground> {
  late String _cacheVersion = DateTime.now().millisecondsSinceEpoch.toString();
  StreamSubscription<List<Map<String, dynamic>>>? _versionSubscription;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _versionSubscription = Supabase.instance.client
        .from('app_settings')
        .stream(primaryKey: ['key'])
        .eq('key', 'feed_background')
        .listen(
          (rows) {
            if (rows.isEmpty) return;
            final version = rows.first['updated_at']?.toString();
            if (version == null || version == _cacheVersion) return;
            _refreshBackground(version);
          },
          onError: (_) {
            // Sin la tabla de configuración se conserva el fondo cargado.
          },
        );
  }

  @override
  void dispose() {
    _versionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshBackground(String nextVersion) async {
    if (_refreshing || !mounted) return;

    _refreshing = true;
    final nextUrl = _publicUrl(version: nextVersion);

    try {
      if (nextUrl == null) return;
      await precacheImage(NetworkImage(nextUrl), context);
      if (!mounted) return;
      setState(() => _cacheVersion = nextVersion);
    } catch (_) {
      // Si la nueva versión no está disponible, se conserva la actual.
    } finally {
      _refreshing = false;
    }
  }

  String? _publicUrl({String? version}) {
    final bucket = widget.bucketId.trim();
    final path = widget.objectPath.trim();

    if (bucket.isEmpty || path.isEmpty) return null;

    try {
      final url = Supabase.instance.client.storage
          .from(bucket)
          .getPublicUrl(path);
      final separator = url.contains('?') ? '&' : '?';
      final cacheVersion = version ?? _cacheVersion;
      return '$url${separator}v=${Uri.encodeQueryComponent(cacheVersion)}';
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _publicUrl();

    if (imageUrl == null) {
      return const SizedBox.expand(
        child: ColoredBox(color: AppColors.background),
      );
    }

    return IgnorePointer(
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 0.7, sigmaY: 0.7),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(color: AppColors.background),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.fromRGBO(3, 3, 10, 0.22),
                    Color.fromRGBO(4, 3, 12, 0.34),
                    Color.fromRGBO(2, 2, 8, 0.45),
                  ],
                  stops: [0, 0.48, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
