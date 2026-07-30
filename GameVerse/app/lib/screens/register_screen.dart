import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool loading = false;

  Future<void> register() async {
    if (usernameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      showMessage("Completa todos los campos.");
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      showMessage("Las contraseñas no coinciden.");
      return;
    }

    setState(() => loading = true);

    try {
      final response = await SupabaseService.client.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
        data: {
          'username': usernameController.text.trim(),
        },
      );

      print("========== SIGN UP ==========");
      print("Usuario: ${response.user}");
      print("ID: ${response.user?.id}");
      print("=============================");

      final user = response.user;

      if (user == null) {
        throw Exception("Supabase no devolvió el usuario.");
      }

      try {
        await SupabaseService.client.from('profiles').insert({
          'id': user.id,
          'username': usernameController.text.trim(),
          'email': emailController.text.trim(),
        });

        print("Perfil creado correctamente.");
      } catch (e) {
        print("ERROR INSERTANDO PERFIL:");
        print(e);
        rethrow;
      }

      if (!mounted) return;

      showMessage("¡Cuenta creada correctamente!");

      Navigator.pop(context);
    } on AuthException catch (e) {
      showMessage(e.message);
      print(e);
    } catch (e) {
      showMessage(e.toString());
      print(e);
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 420,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size: 150),

                const SizedBox(height: 25),

                CustomTextField(
                  controller: usernameController,
                  hint: "Nombre de usuario",
                  icon: Icons.person_outline,
                ),

                const SizedBox(height: 16),

                CustomTextField(
                  controller: emailController,
                  hint: "Correo electrónico",
                  icon: Icons.email_outlined,
                ),

                const SizedBox(height: 16),

                CustomTextField(
                  controller: passwordController,
                  hint: "Contraseña",
                  icon: Icons.lock_outline,
                  obscureText: true,
                ),

                const SizedBox(height: 16),

                CustomTextField(
                  controller: confirmPasswordController,
                  hint: "Confirmar contraseña",
                  icon: Icons.lock_outline,
                  obscureText: true,
                ),

                const SizedBox(height: 28),

                loading
                    ? const CircularProgressIndicator()
                    : CustomButton(
                        text: "Crear cuenta",
                        onPressed: register,
                      ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Ya tengo una cuenta"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}