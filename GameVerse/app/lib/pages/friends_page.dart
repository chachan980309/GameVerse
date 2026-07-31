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
  int selectedTab = 0;

  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> pendingRequests = [];
  List<Map<String, dynamic>> friends = [];
  Set<String> requestedUsers = {};

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    try {
      final result = await _friendService.searchUsers();
      final pending = await _friendService.getPendingRequests();
      final accepted = await _friendService.getAcceptedFriends();

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
        pendingRequests = pending;
        friends = accepted;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> addFriend(String id) async {
    try {
      await _friendService.sendFriendRequest(id);

      if (!mounted) return;

      await loadUsers();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("✅ Solicitud enviada")));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
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
            style: const TextStyle(color: Colors.white54),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              ElevatedButton(
                onPressed: () => setState(() => selectedTab = 0),
                child: const Text("Todos"),
              ),

              const SizedBox(width: 10),

              ElevatedButton(
                onPressed: () => setState(() => selectedTab = 1),
                child: Text("Pendientes (${pendingRequests.length})"),
              ),

              const SizedBox(width: 10),

              ElevatedButton(
                onPressed: () => setState(() => selectedTab = 2),
                child: Text("Amigos (${friends.length})"),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Expanded(
            child: selectedTab == 0
                ? ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final alreadyRequested = requestedUsers.contains(
                        user["id"],
                      );

                      return Card(
                        color: const Color(0xff211D2B),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xff7B4DFF),
                            child: Icon(Icons.person, color: Colors.white),
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
                          trailing: alreadyRequested
                              ? const Icon(Icons.check, color: Colors.green)
                              : ElevatedButton.icon(
                                  onPressed: () async {
                                    await addFriend(user["id"]);
                                  },
                                  icon: const Icon(Icons.person_add),
                                  label: const Text("Agregar"),
                                ),
                        ),
                      );
                    },
                  )
                : selectedTab == 1
                ? pendingRequests.isEmpty
                      ? const Center(
                          child: Text(
                            "No tienes solicitudes pendientes",
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          itemCount: pendingRequests.length,
                          itemBuilder: (context, index) {
                            final request = pendingRequests[index];

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
                                  request["sender"]["username"] ?? "",
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: const Text(
                                  "Quiere ser tu amigo",
                                  style: TextStyle(color: Colors.white54),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.check,
                                        color: Colors.green,
                                      ),
                                      onPressed: () async {
                                        await _friendService.acceptRequest(
                                          request["id"],
                                        );
                                        await loadUsers();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.red,
                                      ),
                                      onPressed: () async {
                                        await _friendService.rejectRequest(
                                          request["id"],
                                        );
                                        await loadUsers();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                : friends.isEmpty
                ? const Center(
                    child: Text(
                      "No tienes amigos",
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final friend = friends[index];

                      return Card(
                        color: const Color(0xff211D2B),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xff7B4DFF),
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(
                            friend["username"] ?? "",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            friend["email"] ?? "",
                            style: const TextStyle(color: Colors.white54),
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
