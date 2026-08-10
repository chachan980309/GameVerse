import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage("Ingresa tu correo electrónico.", error: true);
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await _authService.resetPassword(email);

      if (!mounted) return;

      setState(() {
        _sent = true;
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        "No pudimos enviar el correo. Verifica el correo e inténtalo nuevamente.",
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.redAccent : const Color(0xff6438FF),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D0B14),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xff181522),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: _sent ? _successView() : _formView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xff6438FF).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_reset_rounded,
            color: Color(0xff8B63FF),
            size: 32,
          ),
        ),

        const SizedBox(height: 22),

        const Text(
          "¿Olvidaste tu contraseña?",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        const Text(
          "Ingresa el correo asociado a tu cuenta y te enviaremos un enlace para restablecer tu contraseña.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
        ),

        const SizedBox(height: 28),

        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: "Correo electrónico",
            labelStyle: const TextStyle(color: Colors.white54),
            prefixIcon: const Icon(
              Icons.email_outlined,
              color: Color(0xff8B63FF),
            ),
            filled: true,
            fillColor: const Color(0xff111019),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _loading ? null : _sendResetEmail,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff6438FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    "Enviar enlace",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),

        const SizedBox(height: 16),

        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text(
            "Volver al inicio de sesión",
            style: TextStyle(color: Color(0xff9B7BFF)),
          ),
        ),
      ],
    );
  }

  Widget _successView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            color: Colors.greenAccent,
            size: 32,
          ),
        ),

        const SizedBox(height: 22),

        const Text(
          "Correo enviado",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          "Si existe una cuenta asociada a ${_emailController.text.trim()}, recibirás un correo con las instrucciones para restablecer tu contraseña.",
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 14,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 25),

        const Text(
          "Revisa también tu carpeta de spam.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),

        const SizedBox(height: 20),

        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text(
            "Volver al inicio de sesión",
            style: TextStyle(color: Color(0xff9B7BFF)),
          ),
        ),
      ],
    );
  }
}
