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

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    try {
      final result = await _friendService.searchUsers();

      if (!mounted) return;

      setState(() {
        users = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
        ),
      );
    }
  }

  Future<void> addFriend(String id) async {
    try {
      await _friendService.sendFriendRequest(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Solicitud enviada."),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff17141F),
      appBar: AppBar(
        backgroundColor: const Color(0xff1A1724),
        title: const Text("Buscar jugadores"),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : users.isEmpty
              ? const Center(
                  child: Text(
                    "No hay otros usuarios registrados.",
                    style: TextStyle(color: Colors.white),
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
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xff7B4DFF),
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                          ),
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
                          style: const TextStyle(
                            color: Colors.white54,
                          ),
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: () {
                            addFriend(user["id"]);
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
