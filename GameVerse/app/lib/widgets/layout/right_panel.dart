import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';



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
      setState(() => _profile = _loadProfile());
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
