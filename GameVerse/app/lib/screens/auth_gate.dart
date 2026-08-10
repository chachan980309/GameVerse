import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';
import 'main_screen.dart';
import 'reset_password_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;

  bool _loading = true;
  bool _passwordRecovery = false;

  @override
  void initState() {
    super.initState();

    _initializeAuth();
  }

  // ============================================================
  // INICIALIZAR AUTENTICACIÓN
  // ============================================================

  Future<void> _initializeAuth() async {
    final auth = Supabase.instance.client.auth;

    debugPrint('======================================');
    debugPrint('AUTH GATE INICIANDO');
    debugPrint('======================================');

    // ==========================================================
    // ESCUCHAR CAMBIOS DE AUTENTICACIÓN
    // ==========================================================

    _authSubscription = auth.onAuthStateChange.listen(
      (data) {
        final event = data.event;
        final session = data.session;

        debugPrint('======================================');
        debugPrint('AUTH EVENT: $event');
        debugPrint('SESSION: ${session != null}');

        if (session != null) {
          debugPrint('USER: ${session.user.email}');
        }

        // ======================================================
        // RECUPERACIÓN DE CONTRASEÑA
        // ======================================================

        if (event == AuthChangeEvent.passwordRecovery) {
          debugPrint('PASSWORD_RECOVERY DETECTADO');

          if (!mounted) return;

          setState(() {
            _passwordRecovery = true;
            _loading = false;
          });

          return;
        }

        // ======================================================
        // SESIÓN NORMAL
        // ======================================================

        if (session != null) {
          if (!mounted) return;

          setState(() {
            _passwordRecovery = false;
            _loading = false;
          });

          return;
        }

        // ======================================================
        // SIN SESIÓN
        // ======================================================

        if (!mounted) return;

        setState(() {
          _loading = false;
        });

        debugPrint('SIN SESIÓN');
        debugPrint('======================================');
      },
      onError: (error, stackTrace) {
        debugPrint('ERROR EN AUTH STATE: $error');

        if (!mounted) return;

        setState(() {
          _loading = false;
        });
      },
    );

    // ==========================================================
    // REVISAR SESIÓN INICIAL
    // ==========================================================

    final session = auth.currentSession;

    debugPrint('SESIÓN INICIAL: ${session != null}');

    if (session != null) {
      debugPrint('USUARIO ACTUAL: ${session.user.email}');
    }

    // ==========================================================
    // TERMINAR CARGA
    // ==========================================================

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  // ============================================================
  // LIMPIAR LISTENER
  // ============================================================

  @override
  void dispose() {
    _authSubscription?.cancel();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;

    // ==========================================================
    // CARGANDO
    // ==========================================================

    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xff0D0B14),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xff7B4DFF)),
        ),
      );
    }

    // ==========================================================
    // RECUPERACIÓN DE CONTRASEÑA
    // ==========================================================

    if (_passwordRecovery) {
      return const ResetPasswordScreen();
    }

    // ==========================================================
    // SESIÓN ACTUAL
    // ==========================================================

    final session = auth.currentSession;

    if (session != null) {
      return const MainScreen();
    }

    // ==========================================================
    // SIN SESIÓN
    // ==========================================================

    return const LoginScreen();
  }
}
