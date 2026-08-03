import 'package:flutter/material.dart';

/// Fondo visual predeterminado de Nubzzz.
///
/// Se mantiene separado del contenido para que, en el futuro, un tema Pro
/// pueda usar otro asset sin modificar la estructura del feed.
enum NubzzzAmbientStyle { defaultTheme }

class NubzzzAmbientBackground extends StatelessWidget {
  const NubzzzAmbientBackground({
    super.key,
    this.style = NubzzzAmbientStyle.defaultTheme,
  });

  final NubzzzAmbientStyle style;

  @override
  Widget build(BuildContext context) {
    final assetPath = switch (style) {
      NubzzzAmbientStyle.defaultTheme =>
        'assets/images/nubzzz_default_feed_background.png',
    };

    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              assetPath,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(color: Color(0x16000000)),
            ),
          ],
        ),
      ),
    );
  }
}
