import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _authService = AuthService();

  bool _loading = false;
  bool _success = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ============================================================
  // CAMBIAR CONTRASEÑA
  // ============================================================

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password != confirmPassword) {
      _showMessage("Las contraseñas no coinciden.", error: true);
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await _authService.updatePassword(password);

      if (!mounted) return;

      setState(() {
        _success = true;
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        "No pudimos cambiar la contraseña. "
        "El enlace puede haber expirado.",
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

  // ============================================================
  // MENSAJE
  // ============================================================

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.redAccent : const Color(0xff6438FF),
      ),
    );
  }

  // ============================================================
  // INPUT CONTRASEÑA
  // ============================================================

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: Color(0xff8B63FF),
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.white54,
          ),
        ),
        filled: true,
        fillColor: const Color(0xff111019),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff6438FF), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }

  // ============================================================
  // PANTALLA
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D0B14),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xff181522),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: _success ? _successView() : _resetForm(),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FORMULARIO
  // ============================================================

  Widget _resetForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ICONO
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xff6438FF).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              color: Color(0xff9B7BFF),
              size: 38,
            ),
          ),

          const SizedBox(height: 24),

          // TITULO
          const Text(
            "Nueva contraseña",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            "Crea una nueva contraseña para proteger "
            "tu cuenta de nubzzz.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
          ),

          const SizedBox(height: 28),

          // NUEVA CONTRASEÑA
          _passwordField(
            controller: _passwordController,
            label: "Nueva contraseña",
            obscure: _obscurePassword,
            onToggle: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Ingresa una contraseña";
              }

              if (value.length < 6) {
                return "Mínimo 6 caracteres";
              }

              return null;
            },
          ),

          const SizedBox(height: 16),

          // CONFIRMAR CONTRASEÑA
          _passwordField(
            controller: _confirmPasswordController,
            label: "Confirmar contraseña",
            obscure: _obscureConfirmPassword,
            onToggle: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Confirma tu contraseña";
              }

              if (value != _passwordController.text) {
                return "Las contraseñas no coinciden";
              }

              return null;
            },
          ),

          const SizedBox(height: 12),

          // REQUISITOS
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "• Mínimo 6 caracteres",
              style: TextStyle(
                color: _passwordController.text.length >= 6
                    ? Colors.greenAccent
                    : Colors.white38,
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // BOTÓN
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff6438FF),
                disabledBackgroundColor: const Color(0xff38236F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      "Cambiar contraseña",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 18),

          // VOLVER
          TextButton(
            onPressed: _loading
                ? null
                : () {
                    Navigator.pop(context);
                  },
            child: const Text(
              "Volver al inicio de sesión",
              style: TextStyle(color: Color(0xff9B7BFF)),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ÉXITO
  // ============================================================

  Widget _successView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Colors.greenAccent,
            size: 42,
          ),
        ),

        const SizedBox(height: 24),

        const Text(
          "¡Contraseña actualizada!",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          "Tu contraseña fue cambiada correctamente. "
          "Ya puedes iniciar sesión con tu nueva contraseña.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
        ),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                "/login",
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff6438FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Ir al inicio de sesión",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
