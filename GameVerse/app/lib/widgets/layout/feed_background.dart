import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Fondo decorativo local para evitar egress repetido de Supabase Storage.
class FeedBackground extends StatelessWidget {
  const FeedBackground({
    super.key,
    this.bucketId = 'app-assets',
    this.objectPath = 'feed/default-background.png',
  });

  final String bucketId;
  final String objectPath;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 0.7, sigmaY: 0.7),
              child: Image.asset(
                'assets/images/feed-background.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) =>
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
