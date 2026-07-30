import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';



class PostService {


  final SupabaseClient supabase =
      Supabase.instance.client;






  // OBTENER POSTS

  Future<List<Map<String,dynamic>>> getPosts() async {


    final response = await supabase

        .from('posts')

        .select()

        .order(

          'created_at',

          ascending:false,

        );



    return List<Map<String,dynamic>>.from(response);


  }









  // SUBIR IMAGEN

  Future<String> uploadImage(File image) async {



    final fileName =

    'posts/${DateTime.now().millisecondsSinceEpoch}.png';





    await supabase.storage

        .from('post-images')

        .upload(

          fileName,

          image,

          fileOptions:

          const FileOptions(

            cacheControl:'3600',

            upsert:false,

          ),

        );





    return supabase.storage

        .from('post-images')

        .getPublicUrl(fileName);



  }









  // SUBIR VIDEO

  Future<String> uploadVideo(File video) async {



    final fileName =

    'videos/${DateTime.now().millisecondsSinceEpoch}.mp4';





    await supabase.storage

        .from('post-videos')

        .upload(

          fileName,

          video,

          fileOptions:

          const FileOptions(

            cacheControl:'3600',

            upsert:false,

          ),

        );





    return supabase.storage

        .from('post-videos')

        .getPublicUrl(fileName);



  }









  // CREAR POST

  Future<void> createPost({


    required String username,


    required String content,


    String? image,


    String? video,


    String type = "text",



  }) async {



    await supabase

        .from('posts')

        .insert({



          'username':username,



          'content':content,



          'image':image,



          'video':video,



          'type':type,



          'likes':0,



          'comments':0,



        });



  }





}