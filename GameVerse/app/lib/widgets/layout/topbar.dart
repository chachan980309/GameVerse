import 'dart:async';

import 'package:app/controllers/profile_controller.dart';
import 'package:app/screens/login_screen.dart';
import 'package:app/services/auth_service.dart';
import 'package:flutter/material.dart';

import '../../services/global_search_service.dart';

class TopBar extends StatefulWidget {
  const TopBar({super.key, this.onProfileSelected});

  final ValueChanged<String>? onProfileSelected;

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _searchService = GlobalSearchService();
  final _searchLink = LayerLink();
  final _searchFieldKey = GlobalKey();

  Timer? _debounce;
  OverlayEntry? _searchOverlay;
  GlobalSearchResults _results = GlobalSearchResults.empty();
  bool _searching = false;
  int _searchRequest = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchOverlay?.remove();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _searching = false;
        _results = GlobalSearchResults.empty();
      });
      _removeSearchOverlay();
      return;
    }

    _showSearchOverlay();
    setState(() => _searching = true);
    final request = ++_searchRequest;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await _searchService.search(query);
        if (!mounted || request != _searchRequest) return;
        setState(() {
          _results = results;
          _searching = false;
        });
        _searchOverlay?.markNeedsBuild();
      } catch (_) {
        if (!mounted || request != _searchRequest) return;
        setState(() {
          _results = GlobalSearchResults.empty();
          _searching = false;
        });
        _searchOverlay?.markNeedsBuild();
      }
    });
  }

  void _showSearchOverlay() {
    if (_searchOverlay != null) {
      _searchOverlay!.markNeedsBuild();
      return;
    }
    _searchOverlay = OverlayEntry(builder: (_) => _searchPanel());
    Overlay.of(context, rootOverlay: true).insert(_searchOverlay!);
  }

  void _removeSearchOverlay() {
    _searchOverlay?.remove();
    _searchOverlay = null;
  }

  void _clearSearch() {
    _searchController.clear();
    _onQueryChanged('');
    _searchFocusNode.unfocus();
  }

  void _openUserProfile(GlobalSearchPerson person) {
    _removeSearchOverlay();
    _searchController.clear();
    _searchFocusNode.unfocus();
    widget.onProfileSelected?.call(person.id);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileController();

    return AnimatedBuilder(
      animation: profile,
      builder: (context, _) {
        return Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 25),
          decoration: BoxDecoration(
            color: const Color(0xff111019),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: .06)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xff211D2E),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: CompositedTransformTarget(
                    link: _searchLink,
                    child: TextField(
                      key: _searchFieldKey,
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: _onQueryChanged,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                      hintText: "Buscar jugadores, juegos o amigos...",
                      hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white54,
                        size: 21,
                      ),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.close, color: Colors.white54, size: 19),
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.only(top: 12),
                    ),
                  ),
                  ),
                ),
              ),

              const SizedBox(width: 18),

              _iconButton(Icons.person_add_alt_1),

              const SizedBox(width: 10),

              _iconButton(Icons.chat_bubble_outline),

              const SizedBox(width: 10),

              _iconButton(Icons.notifications_none),

              const SizedBox(width: 22),

              PopupMenuButton(
                offset: const Offset(0, 55),
                color: const Color(0xff211D2E),

                itemBuilder: (context) => [
                  PopupMenuItem(
                    onTap: () async {
                      await AuthService().signOut();

                      if (!context.mounted) return;

                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },

                    child: const Row(
                      children: [
                        Icon(Icons.logout, color: Colors.white70, size: 20),

                        SizedBox(width: 10),

                        Text(
                          "Cerrar sesión",
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],

                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xff7B4DFF),
                          width: 2,
                        ),
                      ),

                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xff6438FF),
                        backgroundImage:
                            profile.avatarUrl != null &&
                                profile.avatarUrl!.isNotEmpty
                            ? NetworkImage(profile.avatarUrl!)
                            : const AssetImage("assets/images/avatar.png")
                                  as ImageProvider,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          profile.username,

                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),

                        const SizedBox(height: 2),

                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,

                              decoration: const BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                              ),
                            ),

                            const SizedBox(width: 6),

                            Text(
                              profile.status,

                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _iconButton(IconData icon) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xff211D2E),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: Colors.white70, size: 20),
    );
  }

  Widget _searchPanel() {
    final renderBox = _searchFieldKey.currentContext?.findRenderObject() as RenderBox?;
    final width = renderBox?.size.width ?? 620.0;
    return CompositedTransformFollower(
      link: _searchLink,
      showWhenUnlinked: false,
      offset: const Offset(0, 52),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width, maxHeight: 320),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: width,
              decoration: BoxDecoration(
                color: const Color(0xFF211D2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8))],
              ),
              child: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                    )
                  : _results.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(22),
                          child: Text('No encontramos resultados.', style: TextStyle(color: Colors.white60)),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shrinkWrap: true,
                          children: [
                            if (_results.people.isNotEmpty) ...[
                              _sectionTitle('Personas'),
                              ..._results.people.map(_personResult),
                            ],
                            if (_results.friends.isNotEmpty) ...[
                              _sectionTitle('Amigos'),
                              ..._results.friends.map(_personResult),
                            ],
                            if (_results.games.isNotEmpty) ...[
                              _sectionTitle('Juegos'),
                              ..._results.games.map(_gameResult),
                            ],
                            if (_results.posts.isNotEmpty) ...[
                              _sectionTitle('Publicaciones'),
                              ..._results.posts.map(_postResult),
                            ],
                          ],
                        ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 5),
        child: Text(title.toUpperCase(), style: const TextStyle(color: Color(0xFFBDAAFF), fontSize: 11, fontWeight: FontWeight.w700)),
      );

  Widget _personResult(GlobalSearchPerson person) => ListTile(
        dense: true,
        onTap: () => _openUserProfile(person),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF6438FF),
          backgroundImage: person.avatarUrl.isEmpty ? null : NetworkImage(person.avatarUrl),
          child: person.avatarUrl.isEmpty ? Text(person.name.isEmpty ? '?' : person.name[0].toUpperCase()) : null,
        ),
        title: Text(person.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(person.status.isNotEmpty ? person.status : person.email, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      );

  Widget _gameResult(String game) => ListTile(
        dense: true,
        leading: const Icon(Icons.sports_esports, color: Color(0xFF7B4DFF)),
        title: Text(game, style: const TextStyle(color: Colors.white, fontSize: 14)),
      );

  Widget _postResult(GlobalSearchPost post) {
    final text = post.content.isNotEmpty ? post.content : post.game;
    return ListTile(
      dense: true,
      leading: const Icon(Icons.article_outlined, color: Colors.white70),
      title: Text(text.isEmpty ? 'Publicación de ${post.username}' : text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text(post.game.isEmpty ? post.username : '${post.username} · ${post.game}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    );
  }
}
