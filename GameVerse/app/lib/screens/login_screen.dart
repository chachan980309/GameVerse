import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final auth = AuthService();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;

  Future<void> login() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      showMessage("Completa todos los campos.");
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await auth.signIn(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } on AuthException catch (e) {
      showMessage(e.message);
    } catch (e) {
      showMessage(e.toString());
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 380,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size: 240),

                const SizedBox(height: 30),

                CustomTextField(
                  controller: emailController,
                  hint: "Correo electrónico",
                  icon: Icons.email_outlined,
                ),

                const SizedBox(height: 18),

                CustomTextField(
                  controller: passwordController,
                  hint: "Contraseña",
                  icon: Icons.lock_outline,
                  obscureText: true,
                ),

                const SizedBox(height: 28),

                loading
                    ? const CircularProgressIndicator()
                    : CustomButton(text: "Iniciar sesión", onPressed: login),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, "/register");
                  },
                  child: const Text("Crear cuenta"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
