import 'package:flutter/material.dart';

import '../services/post_service.dart';

import '../widgets/forms/create_post.dart';

import '../widgets/posts/post_card.dart';

import '../controllers/video_feed_controller.dart';



class FeedPage extends StatefulWidget {


  const FeedPage({

    super.key,

  });



  @override
  State<FeedPage> createState() => _FeedPageState();


}





class _FeedPageState extends State<FeedPage> {



  final PostService postService = PostService();



  final VideoFeedController videoController =
      VideoFeedController();




  List<Map<String,dynamic>> posts = [];



  bool loading = true;







  @override
  void initState(){


    super.initState();


    loadPosts();


  }







  Future<void> loadPosts() async {


    try{


      final data = await postService.getPosts();



      if(!mounted) return;



      setState((){


        posts = data;


        loading = false;


      });



    }catch(e){


      debugPrint(
        "ERROR CARGANDO POSTS: $e"
      );



      if(!mounted) return;



      setState((){


        loading = false;


      });


    }


  }








  @override
  void dispose(){


    videoController.dispose();


    super.dispose();


  }









  @override
  Widget build(BuildContext context){



    return Column(



      crossAxisAlignment:
      CrossAxisAlignment.start,



      children:[






        const Text(


          "Inicio",


          style:TextStyle(


            color:Colors.white,


            fontSize:32,


            fontWeight:FontWeight.bold,


          ),


        ),






        const SizedBox(height:20),







        CreatePost(



          onPostCreated:(){


            loadPosts();


          },


        ),







        const SizedBox(height:20),







        Expanded(



          child:



          loading



          ?



          const Center(



            child:CircularProgressIndicator(



              color:
              Color(0xff6438FF),


            ),



          )





          :





          RefreshIndicator(



            color:
            const Color(0xff6438FF),




            onRefresh:
            loadPosts,





            child:





            ListView.builder(




              padding:
              EdgeInsets.zero,





              physics:
              const AlwaysScrollableScrollPhysics(),






              itemCount:
              posts.length,







              itemBuilder:(context,index){





                return PostCard(



                  post:
                  posts[index],





                  index:
                  index,





                  videoController:
                  videoController,





                );





              },





            ),





          ),






        ),





      ],





    );



  }



}