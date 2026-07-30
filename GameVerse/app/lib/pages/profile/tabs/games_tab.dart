import 'package:flutter/material.dart';

class GamesTab extends StatelessWidget {
  const GamesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      color: const Color(0xff17141F),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "🎮 Mis Juegos",
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),

          _gameCard(
            "League of Legends",
            "Nivel 215 • Oro II",
            Icons.sports_esports,
          ),

          const SizedBox(height: 20),

          _gameCard("Valorant", "Ascendant II", Icons.bolt),

          const SizedBox(height: 20),

          _gameCard("Minecraft", "450 horas", Icons.terrain),
        ],
      ),
    );
  }

  Widget _gameCard(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xff23202E),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurpleAccent, size: 40),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
              Text(subtitle, style: const TextStyle(color: Colors.white54)),
            ],
          ),
        ],
      ),
    );
  }
}
