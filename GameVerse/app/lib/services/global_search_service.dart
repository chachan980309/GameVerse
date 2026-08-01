import 'package:supabase_flutter/supabase_flutter.dart';

import 'friend_service.dart';

/// Searches only data that already exists in GameVerse's Supabase project.
class GlobalSearchService {
  GlobalSearchService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<GlobalSearchResults> search(String query) async {
    final term = query.trim();
    if (term.length < 2) return GlobalSearchResults.empty();

    // Prevent special PostgREST filter characters from changing the query.
    final rawUsers = await _safeList(FriendService().searchUsers());
    final rawPosts = await _safeList(
      _supabase
          .from('posts')
          .select('id, content, game, created_at, profiles(username, avatar_url)')
          .order('created_at', ascending: false)
          .limit(100),
    );

    final currentUser = _supabase.auth.currentUser;
    final friendMatches = <GlobalSearchPerson>[];
    if (currentUser != null) {
      final friendships = await _safeList(FriendService().getAcceptedFriends());
      for (final friendship in friendships) {
        final isSender = friendship['sender_id'] == currentUser.id;
        final rawProfile = friendship[isSender ? 'receiver' : 'sender'];
        if (rawProfile is! Map) continue;
        final profile = Map<String, dynamic>.from(rawProfile);
        if (_matchesProfile(profile, term)) {
          friendMatches.add(GlobalSearchPerson.fromMap(profile));
        }
      }
    }

    final people = rawUsers
        .where((user) => _matchesProfile(user, term))
        .take(6)
        .map(GlobalSearchPerson.fromMap)
        .toList();
    final posts = rawPosts
        .where((post) => _matchesPost(post, term))
        .take(6)
        .map(GlobalSearchPost.fromMap)
        .toList();
    final games = rawPosts
        .map((row) => row['game']?.toString().trim() ?? '')
        .where((game) => game.isNotEmpty && game.toLowerCase().contains(term.toLowerCase()))
        .toSet()
        .take(6)
        .toList();

    return GlobalSearchResults(
      people: people,
      friends: friendMatches,
      games: games,
      posts: posts,
    );
  }

  bool _matchesProfile(Map<String, dynamic> profile, String query) {
    final value = '${profile['username'] ?? ''} ${profile['email'] ?? ''}'
        .toLowerCase();
    return value.contains(query.toLowerCase());
  }

  bool _matchesPost(Map<String, dynamic> post, String query) {
    final rawProfile = post['profiles'];
    final profile = rawProfile is Map ? Map<String, dynamic>.from(rawProfile) : <String, dynamic>{};
    final value = '${post['content'] ?? ''} ${post['game'] ?? ''} ${profile['username'] ?? ''}'.toLowerCase();
    return value.contains(query.toLowerCase());
  }

  Future<List<Map<String, dynamic>>> _safeList(Future<dynamic> request) async {
    try {
      final response = await request;
      return List<Map<String, dynamic>>.from(response as List);
    } catch (_) {
      return [];
    }
  }
}

class GlobalSearchResults {
  const GlobalSearchResults({
    required this.people,
    required this.friends,
    required this.games,
    required this.posts,
  });

  factory GlobalSearchResults.empty() => const GlobalSearchResults(
        people: [],
        friends: [],
        games: [],
        posts: [],
      );

  final List<GlobalSearchPerson> people;
  final List<GlobalSearchPerson> friends;
  final List<String> games;
  final List<GlobalSearchPost> posts;

  bool get isEmpty =>
      people.isEmpty && friends.isEmpty && games.isEmpty && posts.isEmpty;
}

class GlobalSearchPerson {
  const GlobalSearchPerson({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.status,
  });

  factory GlobalSearchPerson.fromMap(Map<String, dynamic> map) {
    return GlobalSearchPerson(
      id: map['id']?.toString() ?? '',
      name: map['username']?.toString() ?? 'Usuario',
      email: map['email']?.toString() ?? '',
      avatarUrl: map['avatar_url']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
    );
  }

  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  final String status;
}

class GlobalSearchPost {
  const GlobalSearchPost({
    required this.id,
    required this.content,
    required this.game,
    required this.username,
    required this.avatarUrl,
  });

  factory GlobalSearchPost.fromMap(Map<String, dynamic> map) {
    final rawProfile = map['profiles'];
    final profile = rawProfile is Map ? Map<String, dynamic>.from(rawProfile) : <String, dynamic>{};
    return GlobalSearchPost(
      id: map['id']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      game: map['game']?.toString() ?? '',
      username: profile['username']?.toString() ?? 'Usuario',
      avatarUrl: profile['avatar_url']?.toString() ?? '',
    );
  }

  final String id;
  final String content;
  final String game;
  final String username;
  final String avatarUrl;
}
