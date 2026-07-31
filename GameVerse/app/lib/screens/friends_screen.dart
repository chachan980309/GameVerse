import 'package:flutter/material.dart';

import '../services/friend_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FriendService _friendService = FriendService();

  bool loading = true;
  List<Map<String, dynamic>> users = [];
  Set<String> requestedUsers = {};

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    setState(() {
      loading = true;
    });

    try {
      final result = await _friendService.searchUsers();

      requestedUsers.clear();

      for (final user in result) {
        final exists = await _friendService.hasFriendRequest(user["id"]);

        if (exists) {
          requestedUsers.add(user["id"]);
        }
      }

      if (!mounted) return;

      setState(() {
        users = result;
        loading = false;
      });
    } catch (e) {
      debugPrint("Error cargando usuarios: $e");

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> addFriend(String id) async {
    try {
      await _friendService.sendFriendRequest(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Solicitud enviada"),
          backgroundColor: Colors.green,
        ),
      );

      loadUsers();
    } catch (e) {
      debugPrint("Error enviando solicitud: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff17141F),
      appBar: AppBar(
        backgroundColor: const Color(0xff1A1724),
        elevation: 0,
        title: const Text("Buscar jugadores"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
          ? const Center(
              child: Text(
                "No hay otros usuarios registrados.",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];

                return Card(
                  color: const Color(0xff211D2B),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xff7B4DFF),
                      backgroundImage:
                          user["avatar_url"] != null &&
                              user["avatar_url"].toString().isNotEmpty
                          ? NetworkImage(user["avatar_url"])
                          : null,
                      child:
                          user["avatar_url"] == null ||
                              user["avatar_url"].toString().isEmpty
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    title: Text(
                      user["username"] ?? "",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      user["email"] ?? "",
                      style: const TextStyle(color: Colors.white54),
                    ),
                    trailing: requestedUsers.contains(user["id"])
                        ? ElevatedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.check),
                            label: const Text("Enviada"),
                          )
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff7B4DFF),
                            ),
                            onPressed: () async {
                              await addFriend(user["id"]);
                              await loadUsers();
                            },
                            icon: const Icon(Icons.person_add),
                            label: const Text("Agregar"),
                          ),
                  ),
                );
              },
            ),
    );
  }
}
