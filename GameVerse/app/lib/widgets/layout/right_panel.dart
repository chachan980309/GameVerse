import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/profile_controller.dart';
import '../../models/post_model.dart';
import '../../models/user_game.dart';
import '../../services/post_service.dart';
import '../../services/user_games_service.dart';
import '../profile/edit_profile_dialog.dart';



class RightPanel extends StatelessWidget {


  const RightPanel({

    super.key,

  });






  @override
  Widget build(BuildContext context) {


    final friends = [


      {
        "name":"Daniel",
        "online":true,
        "game":"Apex Legends"
      },


      {
        "name":"Camila",
        "online":true,
        "game":"Valorant"
      },


      {
        "name":"Juan",
        "online":false,
        "game":"Desconectado"
      },


      {
        "name":"Laura",
        "online":true,
        "game":"Minecraft"
      },


      {
        "name":"Carlos",
        "online":true,
        "game":"Fortnite"
      },


    ];





    return Container(



      width:300,



      padding:

      const EdgeInsets.all(18),





      decoration:

      const BoxDecoration(



        color:

        Color(0xff111019),




        border:

        Border(

          left:

          BorderSide(

            color:

            Color(0xff252231),

          ),

        ),



      ),







      child:Column(



        crossAxisAlignment:

        CrossAxisAlignment.start,



        children:[







          const SizedBox(height:10),






          const Text(



            "Amigos",



            style:

            TextStyle(



              color:

              Colors.white,



              fontSize:20,



              fontWeight:

              FontWeight.bold,



            ),



          ),





          const SizedBox(height:5),





          Text(



            "${friends.where((f)=>f['online']==true).length} conectados",



            style:

            const TextStyle(



              color:

              Colors.greenAccent,



              fontSize:12,



            ),



          ),






          const SizedBox(height:20),







          Expanded(



            child:

            ListView.builder(



              itemCount:

              friends.length,




              itemBuilder:(context,index){



                final friend = friends[index];



                final online =
                friend["online"] as bool;





                return Container(



                  margin:

                  const EdgeInsets.only(

                    bottom:12,

                  ),






                  child:Row(



                    children:[






                      Stack(



                        children:[





                          Container(



                            padding:

                            const EdgeInsets.all(2),




                            decoration:

                            BoxDecoration(



                              shape:

                              BoxShape.circle,



                              border:

                              Border.all(



                                color:

                                const Color(0xff7047FF),



                                width:2,



                              ),



                            ),



                            child:

                            const CircleAvatar(



                              radius:23,



                              backgroundColor:

                              Color(0xff6438FF),




                              child:

                              Icon(



                                Icons.person,



                                color:

                                Colors.white,



                              ),



                            ),



                          ),






                          Positioned(



                            right:2,

                            bottom:2,



                            child:

                            Container(



                              width:12,

                              height:12,



                              decoration:

                              BoxDecoration(



                                color:

                                online

                                ? Colors.greenAccent

                                : Colors.grey,



                                shape:

                                BoxShape.circle,



                                border:

                                Border.all(



                                  color:

                                  const Color(0xff111019),



                                  width:2,



                                ),



                              ),



                            ),



                          )





                        ],



                      ),








                      const SizedBox(width:12),








                      Expanded(



                        child:

                        Column(



                          crossAxisAlignment:

                          CrossAxisAlignment.start,



                          children:[





                            Text(



                              friend["name"] as String,



                              style:

                              const TextStyle(



                                color:

                                Colors.white,



                                fontWeight:

                                FontWeight.bold,



                                fontSize:14,



                              ),



                            ),





                            const SizedBox(height:3),






                            Row(



                              children:[



                                Icon(



                                  Icons.sports_esports,



                                  size:12,



                                  color:

                                  online

                                  ? Colors.greenAccent

                                  : Colors.white54,



                                ),





                                const SizedBox(width:4),





                                Flexible(



                                  child:

                                  Text(



                                    friend["game"] as String,



                                    overflow:

                                    TextOverflow.ellipsis,



                                    style:

                                    TextStyle(



                                      color:

                                      online

                                      ? Colors.white70

                                      : Colors.white54,



                                      fontSize:11,



                                    ),



                                  ),



                                )




                              ],



                            )




                          ],



                        ),



                      ),






                      const Icon(



                        Icons.chevron_right,



                        color:

                        Colors.white38,



                        size:20,



                      )





                    ],



                  ),



                );



              },



            ),



          ),







          const SizedBox(height:15),







          SizedBox(



            width:

            double.infinity,



            height:42,



            child:

            ElevatedButton(



              onPressed:(){},




              style:

              ElevatedButton.styleFrom(



                backgroundColor:

                const Color(0xff6438FF),



                shape:

                RoundedRectangleBorder(



                  borderRadius:

                  BorderRadius.circular(12),



                ),



              ),




              child:

              const Text(



                "Agregar amigo",



                style:

                TextStyle(



                  color:

                  Colors.white,



                  fontWeight:

                  FontWeight.bold,



                ),



              ),



            ),



          )







        ],



      ),



    );


  }


}

/// Contextual right column shown while viewing another user's profile.
class PublicProfilePanel extends StatefulWidget {
  const PublicProfilePanel({super.key, required this.userId});

  final String userId;

  @override
  State<PublicProfilePanel> createState() => _PublicProfilePanelState();
}

class _PublicProfilePanelState extends State<PublicProfilePanel> {
  late Future<Map<String, dynamic>?> _profile;

  @override
  void initState() {
    super.initState();
    _profile = _loadProfile();
  }

  @override
  void didUpdateWidget(covariant PublicProfilePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      setState(() {
        _profile = _loadProfile();
      });
    }
  }

  Future<Map<String, dynamic>?> _loadProfile() async {
    final profile = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', widget.userId)
        .maybeSingle();
    return profile == null ? null : Map<String, dynamic>.from(profile);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111019),
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          final profile = snapshot.data;
          if (profile == null) return const SizedBox();

          final name = profile['username']?.toString() ?? 'Usuario';
          final bio = profile['bio']?.toString() ?? '';
          final status = profile['status']?.toString() ?? '';
          final email = profile['email']?.toString() ?? '';
          final location = profile['location']?.toString() ?? '';
          final platform = profile['platform']?.toString() ?? '';
          final role = profile['role']?.toString() ?? '';
          final favoriteGame = profile['favorite_game']?.toString() ?? '';

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Acerca de $name', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            if (bio.isNotEmpty)
              Text(bio, style: const TextStyle(color: Colors.white70, height: 1.4)),
            if (status.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.circle, color: Colors.greenAccent, size: 10),
                const SizedBox(width: 8),
                Expanded(child: Text(status, style: const TextStyle(color: Colors.white60))),
              ]),
            ],
            if (email.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(children: [
                const Icon(Icons.mail_outline, color: Colors.white54, size: 17),
                const SizedBox(width: 8),
                Expanded(child: Text(email, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60))),
              ]),
            ],
            if (location.isNotEmpty) ...[
              const SizedBox(height: 14),
              _detail(Icons.location_on_outlined, location),
            ],
            if (platform.isNotEmpty) ...[
              const SizedBox(height: 14),
              _detail(Icons.desktop_windows_outlined, platform),
            ],
            if (role.isNotEmpty) ...[
              const SizedBox(height: 14),
              _detail(Icons.shield_outlined, role),
            ],
            if (favoriteGame.isNotEmpty) ...[
              const SizedBox(height: 14),
              _detail(Icons.sports_esports_outlined, favoriteGame),
            ],
          ]);
        },
      ),
    );
  }

  Widget _detail(IconData icon, String text) => Row(children: [
        Icon(icon, color: const Color(0xFF9A78FF), size: 17),
        const SizedBox(width: 8),
        Expanded(child: Text(text, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60))),
      ]);
}

class MyProfilePanel extends StatefulWidget {
  const MyProfilePanel({super.key});

  @override
  State<MyProfilePanel> createState() => _MyProfilePanelState();
}

class _MyProfilePanelState extends State<MyProfilePanel> {
  final _profile = ProfileController.instance;
  late Future<List<UserGame>> _games = UserGamesService().getMyGames();
  late Future<List<PostModel>> _posts = _loadPosts();
  String? _loadedProfileId;

  Future<List<PostModel>> _loadPosts() async {
    final id = _profile.userId;
    if (id == null) return [];
    return PostService().getUserPosts(id);
  }

  void _refresh() {
    setState(() {
      _games = UserGamesService().getMyGames();
      _posts = _loadPosts();
    });
  }

  @override
  Widget build(BuildContext context) {
    _ensureProfileData();
    return Container(
        color: const Color(0xFF111019),
        padding: const EdgeInsets.all(14),
        child: AnimatedBuilder(
          animation: _profile,
          builder: (context, _) => ListView(children: [
            _aboutCard(context),
            const SizedBox(height: 14),
            _activityCard(),
            const SizedBox(height: 14),
            _gamesCard(context),
          ]),
        ),
      );
  }

  void _ensureProfileData() {
    if (_loadedProfileId == _profile.userId) return;
    _loadedProfileId = _profile.userId;
    _games = UserGamesService().getMyGames();
    _posts = _loadPosts();
  }

  Widget _aboutCard(BuildContext context) => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Acerca de ${_profile.username}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
            IconButton(
              tooltip: 'Editar perfil',
              onPressed: () async {
                await showEditProfileDialog(context);
                _refresh();
              },
              icon: const Icon(Icons.edit_outlined, color: Color(0xFFAF8CFF), size: 19),
            ),
          ]),
          if (_profile.bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_profile.bio, style: const TextStyle(color: Colors.white70, height: 1.35)),
          ],
          const SizedBox(height: 14),
          _detail(Icons.circle, _profile.status, color: Colors.greenAccent),
          if (_profile.location.isNotEmpty) _detail(Icons.location_on_outlined, _profile.location),
          if (_profile.platform.isNotEmpty) _detail(Icons.desktop_windows_outlined, _profile.platform),
          if (_profile.role.isNotEmpty) _detail(Icons.shield_outlined, _profile.role),
          if (_profile.favoriteGame.isNotEmpty) _detail(Icons.sports_esports_outlined, _profile.favoriteGame),
        ]),
      );

  Widget _activityCard() => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Actividad reciente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          FutureBuilder<List<PostModel>>(
            future: _posts,
            builder: (context, snapshot) {
              final posts = snapshot.data ?? [];
              if (snapshot.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
              if (posts.isEmpty) return const Text('Aún no has publicado actividad.', style: TextStyle(color: Colors.white54, fontSize: 12));
              return Column(children: posts.take(3).map((post) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const CircleAvatar(radius: 15, backgroundColor: Color(0xFF30274B), child: Icon(Icons.article_outlined, color: Color(0xFFAF8CFF), size: 16)),
                  const SizedBox(width: 9),
                  Expanded(child: Text(post.content.isEmpty ? 'Publicó contenido nuevo' : post.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                ]),
              )).toList());
            },
          ),
        ]),
      );

  Widget _gamesCard(BuildContext context) => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('Juegos favoritos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
            TextButton(onPressed: () => _showAllGames(context), child: const Text('Ver todos')),
          ]),
          FutureBuilder<List<UserGame>>(
            future: _games,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
              final games = snapshot.data ?? [];
              final favorites = games.where((game) => game.isFavorite).toList();
              final shown = favorites.isEmpty ? games.take(3).toList() : favorites.take(4).toList();
              if (shown.isEmpty) return const Text('Añade juegos desde la pestaña Juegos.', style: TextStyle(color: Colors.white54, fontSize: 12));
              return Column(children: shown.map((game) => Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(children: [
                  _gameArtwork(game),
                  const SizedBox(width: 9),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(game.gameName, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('${game.hoursPlayed} horas', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ])),
                ]),
              )).toList());
            },
          ),
        ]),
      );

  Future<void> _showAllGames(BuildContext context) async {
    final games = await UserGamesService().getMyGames();
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B1828),
      builder: (context) => SafeArea(child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(18),
        children: [
          const Text('Mis juegos', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...games.map((game) => ListTile(leading: _gameArtwork(game, size: 42), title: Text(game.gameName, style: const TextStyle(color: Colors.white)), subtitle: Text('${game.hoursPlayed} horas', style: const TextStyle(color: Colors.white54)))),
        ],
      )),
    );
  }

  Widget _gameArtwork(UserGame game, {double size = 30}) {
    final imageUrl = game.imageUrl.trim();
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF30274B),
        borderRadius: BorderRadius.circular(size * .22),
      ),
      child: Icon(
        Icons.sports_esports_rounded,
        color: const Color(0xFFAF8CFF),
        size: size * .56,
      ),
    );

    if (imageUrl.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .22),
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFF1B1927), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2D2940))),
        child: child,
      );

  Widget _detail(IconData icon, String text, {Color color = const Color(0xFFAF8CFF)}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [Icon(icon, color: color, size: 16), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(color: Colors.white60, fontSize: 12)))]),
      );
}
