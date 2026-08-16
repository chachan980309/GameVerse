import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controllers/profile_controller.dart';

import 'screens/auth_gate.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // MEDIA KIT
  // ============================================================

  MediaKit.ensureInitialized();

  // ============================================================
  // CARGAR VARIABLES DE ENTORNO
  // ============================================================

  try {
    await dotenv.load(fileName: 'supabase.env');
  } catch (e) {
    debugPrint(
      'Advertencia: No se pudo cargar el archivo .env ($e). '
      'Se intentarán usar las variables de compilación.',
    );
  }

  final supabaseUrl =
      dotenv.env['SUPABASE_URL'] ??
      const String.fromEnvironment('SUPABASE_URL');

  final supabaseKey =
      dotenv.env['SUPABASE_ANON_KEY'] ??
      const String.fromEnvironment('SUPABASE_ANON_KEY');

  // ============================================================
  // VALIDAR CONFIGURACIÓN
  // ============================================================

  if (supabaseUrl.isEmpty) {
    debugPrint('ERROR: SUPABASE_URL está vacío.');
  }

  if (supabaseKey.isEmpty) {
    debugPrint('ERROR: SUPABASE_ANON_KEY está vacío.');
  }

  // ============================================================
  // INICIALIZAR SUPABASE
  // ============================================================
  //
  // Usamos el flujo IMPLICIT para Flutter Web.
  //
  // Supabase detectará automáticamente los callbacks
  // provenientes del correo de recuperación.
  //
  // NO hacemos exchangeCodeForSession manualmente.
  //
  // ============================================================

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
      detectSessionInUri: true,
      autoRefreshToken: true,
    ),
  );

  // ============================================================
  // DEBUG AUTH
  // ============================================================

  Supabase.instance.client.auth.onAuthStateChange.listen(
    (data) {
      debugPrint('======================================');

      debugPrint('AUTH EVENT: ${data.event}');

      debugPrint('SESSION: ${data.session != null}');

      if (data.session != null) {
        debugPrint('USER: ${data.session!.user.email}');
      }

      if (data.event == AuthChangeEvent.passwordRecovery) {
        debugPrint('PASSWORD_RECOVERY DETECTADO');
      }

      debugPrint('======================================');
    },
    onError: (error, stackTrace) {
      debugPrint('ERROR AUTH STATE: $error');
    },
  );

  // ============================================================
  // INICIAR APLICACIÓN
  // ============================================================

  runApp(const MyApp());
}

// ================================================================
// MY APP
// ================================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: ProfileController.instance,

      child: MaterialApp(
        debugShowCheckedModeBanner: false,

        title: 'nubzzz',

        // ========================================================
        // TEMA
        // ========================================================
        theme: ThemeData(
          brightness: Brightness.dark,

          scaffoldBackgroundColor: const Color(0xff17141f),

          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,

            brightness: Brightness.dark,
          ),

          inputDecorationTheme: const InputDecorationTheme(
            filled: true,

            fillColor: Color(0xff111019),
          ),
        ),

        // ========================================================
        // RUTAS
        // ========================================================
        routes: {
          // ------------------------------------------------------
          // LOGIN
          // ------------------------------------------------------
          '/login': (context) {
            return const LoginScreen();
          },

          // ------------------------------------------------------
          // REGISTRO
          // ------------------------------------------------------
          '/register': (context) {
            return const RegisterScreen();
          },

          // ------------------------------------------------------
          // RECUPERAR CONTRASEÑA
          // ------------------------------------------------------
          '/forgot-password': (context) {
            return const ForgotPasswordScreen();
          },

          // ------------------------------------------------------
          // CAMBIAR CONTRASEÑA
          // ------------------------------------------------------
          '/reset-password': (context) {
            return const ResetPasswordScreen();
          },

          // ------------------------------------------------------
          // AJUSTES
          // ------------------------------------------------------
          '/settings': (context) {
            return const SettingsScreen();
          },
        },

        // Las rutas de la aplicación se conservan en el navegador. Así Atrás
        // vuelve a la sección anterior de nubzzz en vez de salir del sitio.
        onGenerateRoute: (settings) {
          final uri = Uri.parse(settings.name ?? '/');
          final path = uri.path.isEmpty ? '/' : uri.path;

          if (path == '/' ||
              path == '/inicio' ||
              path == '/profile' ||
              path.startsWith('/profile/') ||
              path == '/amigos' ||
              path == '/canales-voz' ||
              path == '/torneos' ||
              path == '/clanes') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => AuthGate(initialPath: path),
            );
          }

          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const AuthGate(initialPath: '/inicio'),
          );
        },
      ),
    );
  }
}
