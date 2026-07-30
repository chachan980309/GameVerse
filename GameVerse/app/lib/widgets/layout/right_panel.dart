import 'package:flutter/material.dart';



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