import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/nubzzz-logo.png',
          width: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        if (showText) ...[
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
