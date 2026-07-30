import 'package:flutter/material.dart';

import '../services/friend_service.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
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
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> addFriend(String id) async {
    try {
      await _friendService.sendFriendRequest(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Solicitud enviada"),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Amigos",
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            "${users.length} usuarios encontrados",
            style: const TextStyle(
              color: Colors.white54,
            ),
          ),

          const SizedBox(height: 25),

          Expanded(
            child: users.isEmpty
                ? const Center(
                    child: Text(
                      "No hay usuarios disponibles.",
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xff211D2B),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          leading: const CircleAvatar(
                            radius: 24,
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
                            onPressed: () => addFriend(user["id"]),
                            icon: const Icon(Icons.person_add),
                            label: const Text("Agregar"),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}