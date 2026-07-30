import 'package:flutter/material.dart';

import 'dashboard_card.dart';

class StatsSection extends StatelessWidget {
  const StatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      childAspectRatio: 2.6,
      children: const [
        DashboardCard(
          title: "Amigos",
          value: "24",
          icon: Icons.people,
          color: Colors.blue,
        ),
        DashboardCard(
          title: "Chats",
          value: "12",
          icon: Icons.chat,
          color: Colors.green,
        ),
        DashboardCard(
          title: "Juegos",
          value: "18",
          icon: Icons.sports_esports,
          color: Colors.orange,
        ),
        DashboardCard(
          title: "Logros",
          value: "53",
          icon: Icons.emoji_events,
          color: Colors.amber,
        ),
      ],
    );
  }
}