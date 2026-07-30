import 'package:flutter/material.dart';

class ActivityPanel extends StatelessWidget {
  const ActivityPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final activities = [
      {
        "title": "Daniel inició una partida",
        "subtitle": "Fortnite • hace 2 min",
        "icon": Icons.sports_esports,
        "color": Colors.green,
      },
      {
        "title": "Laura aceptó tu solicitud",
        "subtitle": "Ahora son amigos",
        "icon": Icons.person_add_alt_1,
        "color": Colors.blue,
      },
      {
        "title": "Nuevo logro desbloqueado",
        "subtitle": "Explorador Nivel 1",
        "icon": Icons.emoji_events,
        "color": Colors.amber,
      },
      {
        "title": "Carlos te envió un mensaje",
        "subtitle": "Hace 12 minutos",
        "icon": Icons.chat_bubble,
        "color": Colors.deepPurpleAccent,
      },
      {
        "title": "Minecraft actualizado",
        "subtitle": "Versión disponible",
        "icon": Icons.download,
        "color": Colors.orange,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xff211D2B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Actividad reciente",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          ...activities.map(
            (activity) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: (activity["color"] as Color).withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      activity["icon"] as IconData,
                      color: activity["color"] as Color,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity["title"] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activity["subtitle"] as String,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}