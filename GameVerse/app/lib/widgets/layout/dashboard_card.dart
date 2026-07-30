import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const DashboardCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xff211D2B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: .05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: 30,
            ),
          ),

          const SizedBox(width: 18),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.arrow_forward_ios,
            color: Colors.white24,
            size: 16,
          ),
        ],
      ),
    );
  }
}