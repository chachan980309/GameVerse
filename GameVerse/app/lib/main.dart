import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controllers/profile_controller.dart';
import 'controllers/clan_controller.dart';
import 'screens/auth_gate.dart';
import 'screens/register_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar MediaKit para videos
  MediaKit.ensureInitialized();

  // Leer variables de compilación (vía --dart-define o --dart-define-from-file)
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  String finalUrl = supabaseUrl;
  String finalKey = supabaseKey;

  if (finalUrl.isEmpty || finalKey.isEmpty) {
    debugPrint(
      '⚠️ ADVERTENCIA: Las variables de entorno SUPABASE_URL o SUPABASE_ANON_KEY no están definidas. '
      'Se usarán los valores reales de Supabase por defecto para el desarrollo local.'
    );
    if (finalUrl.isEmpty) {
      finalUrl = 'https://kspeynuvzzglafckkiza.supabase.co';
    }
    if (finalKey.isEmpty) {
      finalKey = 'sb_publishable_3adr9c84mh5xpbvFs6nEDA_AtKjC-7m';
    }
  }

  // Inicializar Supabase
  try {
    await Supabase.initialize(
      url: finalUrl,
      publishableKey: finalKey,
    );
  } catch (e) {
    debugPrint('❌ Error crítico al inicializar Supabase: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ProfileController>.value(value: ProfileController.instance),
        ChangeNotifierProvider<ClanController>.value(value: ClanController.instance),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,

        title: "nubzzz",

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
      ),
    );
  }
}
