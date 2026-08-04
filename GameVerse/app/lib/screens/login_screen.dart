import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'main_screen.dart';

String _storageUrl(String folder, String file) =>
    Supabase.instance.client.storage
        .from('app-assets')
        .getPublicUrl('$folder/$file');

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
  bool _obscure = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (emailController.text.trim().isEmpty || passwordController.text.isEmpty) {
      _showMessage('Completa todos los campos.');
      return;
    }
    setState(() => loading = true);
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
      _showMessage(e.message);
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff08060F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Imagen de fondo completa sin recorte ─────────────────────────
          Image.network(
            _storageUrl('login', 'login_background.png'),
            fit: BoxFit.fill,
            errorBuilder: (context, e, stack) => Container(
              color: const Color(0xff0D0620),
            ),
          ),

          // ── Formulario sobre el cuadro oscuro de la imagen ───────────────
          Align(
            alignment: const Alignment(0.80, 0.0),
            child: FractionallySizedBox(
              widthFactor: 0.36,
              heightFactor: 0.90,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Badge superior
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('// ', style: TextStyle(color: Color(0xff8B4DFF), fontSize: 12, fontWeight: FontWeight.w700)),
                            Text('BIENVENIDO DE NUEVO', style: TextStyle(color: Color(0xff8B4DFF), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                            Text(' //', style: TextStyle(color: Color(0xff8B4DFF), fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Título
                        RichText(
                          textAlign: TextAlign.center,
                          text: const TextSpan(
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.1),
                            children: [
                              TextSpan(text: 'Inicia ', style: TextStyle(color: Colors.white)),
                              TextSpan(text: 'sesión', style: TextStyle(color: Color(0xff8B4DFF))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Accede a tu cuenta y continúa tu aventura.',
                          style: TextStyle(color: Color(0xff8D8797), fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Campo email
                        _field(
                          controller: emailController,
                          hint: 'Correo electrónico',
                          icon: Icons.email_outlined,
                          onSubmit: (_) => FocusScope.of(context).nextFocus(),
                        ),
                        const SizedBox(height: 14),

                        // Campo contraseña
                        _field(
                          controller: passwordController,
                          hint: 'Contraseña',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscure,
                          suffix: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xff8D8797),
                              size: 18,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          onSubmit: (_) => login(),
                        ),
                        const SizedBox(height: 8),

                        // Recordarme + olvidaste
                        Row(
                          children: [
                            const SizedBox(width: 4),
                            const Text('¿Olvidaste tu contraseña?',
                                style: TextStyle(color: Color(0xff8B4DFF), fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Botón iniciar sesión
                        SizedBox(
                          height: 52,
                          child: loading
                              ? const Center(child: CircularProgressIndicator(color: Color(0xff8B4DFF)))
                              : FilledButton(
                                  onPressed: login,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xff8B4DFF),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Iniciar sesión',
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward_rounded, size: 18),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(height: 20),

                        // Divisor
                        Row(
                          children: const [
                            Expanded(child: Divider(color: Color(0xff2A1F45))),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('o', style: TextStyle(color: Color(0xff555064), fontSize: 13)),
                            ),
                            Expanded(child: Divider(color: Color(0xff2A1F45))),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Crear cuenta
                        SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/register'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xff2A1F45), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.person_add_outlined, size: 18, color: Color(0xff8B4DFF)),
                            label: const Text('Crear una cuenta',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Footer
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.shield_outlined, color: Color(0xff555064), size: 14),
                            SizedBox(width: 6),
                            Text(
                              'Tu información está protegida.\nJugamos limpio, siempre.',
                              style: TextStyle(color: Color(0xff555064), fontSize: 11, height: 1.5),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    void Function(String)? onSubmit,
  }) =>
      TextField(
        controller: controller,
        obscureText: obscure,
        onSubmitted: onSubmit,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xff555064)),
          prefixIcon: Icon(icon, color: const Color(0xff8D8797), size: 18),
          suffixIcon: suffix,
          filled: true,
          fillColor: const Color(0xff130F1E),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xff2A1F45)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xff2A1F45)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xff8B4DFF), width: 1.5),
          ),
        ),
      );
}
