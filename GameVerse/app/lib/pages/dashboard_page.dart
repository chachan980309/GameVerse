import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../screens/login_screen.dart';
import '../widgets/layout/activity_panel.dart';
import '../widgets/layout/stats_section.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final auth = AuthService();

  String username = "Cargando...";
  String status = "offline";
  String bio = "";

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final profile = await ProfileService().getProfile();

      if (!mounted) return;

      setState(() {
        username = profile?['username'] ?? auth.currentUser?.email ?? "Usuario";

        status = profile?['status'] ?? "offline";

        bio = profile?['bio'] ?? "Sin descripción";
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        username = auth.currentUser?.email ?? "Usuario";
        status = "offline";
        bio = "Sin descripción";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "¡Bienvenido!",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              username,
              style: const TextStyle(color: Colors.white60, fontSize: 16),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                CircleAvatar(
                  radius: 5,
                  backgroundColor: status == "online"
                      ? Colors.greenAccent
                      : Colors.grey,
                ),

                const SizedBox(width: 8),

                Text(
                  status == "online" ? "En línea" : "Desconectado",
                  style: TextStyle(
                    color: status == "online"
                        ? Colors.greenAccent
                        : Colors.white54,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 5),

            Text(
              bio,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),

            const SizedBox(height: 35),

            const StatsSection(),

            const SizedBox(height: 35),

            const ActivityPanel(),

            const SizedBox(height: 35),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),

              onPressed: () async {
                await auth.signOut();

                if (!context.mounted) return;

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },

              icon: const Icon(Icons.logout),

              label: const Text("Cerrar sesión"),
            ),
          ],
        ),
      ),
    );
  }
}
