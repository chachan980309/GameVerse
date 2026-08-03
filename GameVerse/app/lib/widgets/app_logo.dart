import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppLogo extends StatefulWidget {
  const AppLogo({
    super.key,
    this.size = 280,
    this.showText = false,
    this.bucketId = 'app-assets',
    this.objectPath = 'branding/app-logo.png',
  });

  final double size;
  final bool showText;
  final String bucketId;
  final String objectPath;

  @override
  State<AppLogo> createState() => _AppLogoState();
}

class _AppLogoState extends State<AppLogo> {
  late String _cacheVersion = DateTime.now().millisecondsSinceEpoch.toString();
  StreamSubscription<List<Map<String, dynamic>>>? _versionSubscription;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _versionSubscription = Supabase.instance.client
        .from('app_settings')
        .stream(primaryKey: ['key'])
        .eq('key', 'app_logo')
        .listen(
          (rows) {
            if (rows.isEmpty) return;
            final version = rows.first['updated_at']?.toString();
            if (version == null || version == _cacheVersion) return;
            _refreshLogo(version);
          },
          onError: (_) {
            // El logo local permanece disponible si no existe la configuración.
          },
        );
  }

  @override
  void dispose() {
    _versionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshLogo(String nextVersion) async {
    if (_refreshing || !mounted) return;
    _refreshing = true;

    try {
      await precacheImage(NetworkImage(_publicUrl(nextVersion)), context);
      if (!mounted) return;
      setState(() => _cacheVersion = nextVersion);
    } catch (_) {
      // Si el archivo remoto no está disponible se conserva el logo actual.
    } finally {
      _refreshing = false;
    }
  }

  String _publicUrl([String? version]) {
    final url = Supabase.instance.client.storage
        .from(widget.bucketId)
        .getPublicUrl(widget.objectPath);
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}v=${Uri.encodeQueryComponent(version ?? _cacheVersion)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.network(
          _publicUrl(),
          width: widget.size,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => Image.asset(
            'assets/images/nubzzz_logo.png',
            width: widget.size,
            fit: BoxFit.contain,
          ),
        ),
        if (widget.showText) ...[
          const SizedBox(height: 2),
          const Text(
            'nubzzz',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Conecta • Juega • Comparte',
            style: TextStyle(fontSize: 15, color: Colors.white70),
          ),
        ],
      ],
    );
  }
}
