import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 280,
    this.showText = false,
  });

  final double size;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/nubzzz_logo.png',
          width: size,
          fit: BoxFit.contain,
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
            style: TextStyle(
              fontSize: 15,
              color: Colors.white70,
            ),
          ),
        ],
      ],
    );
  }
}
