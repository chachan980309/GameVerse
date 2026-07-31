import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_gate.dart';
import 'screens/register_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar MediaKit para videos
  MediaKit.ensureInitialized();

  // Inicializar Supabase
  await Supabase.initialize(
    url: "https://kspeynuvzzglafckkiza.supabase.co",
    publishableKey: "sb_publishable_3adr9c84mh5xpbvFs6nEDA_AtKjC-7m",
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: "GameVerse",

      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xff17141f),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),

      routes: {"/register": (context) => const RegisterScreen()},

      home: AuthGate(),
    );
  }
}
