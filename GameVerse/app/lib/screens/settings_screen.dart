import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int selectedSection = 0;

  final List<_SettingsItem> sections = const [
    _SettingsItem(
      icon: Icons.person_rounded,
      title: 'Cuenta',
      subtitle: 'Configuración de tu cuenta',
    ),
    _SettingsItem(
      icon: Icons.mic_rounded,
      title: 'Ajustes de voz',
      subtitle: 'Micrófono, entrada y configuración de voz',
    ),
  ];

  final SupabaseClient _supabase = Supabase.instance.client;

  User? get _currentUser => _supabase.auth.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff17141f),
      body: SafeArea(
        child: Row(
          children: [
            // =========================================================
            // MENÚ LATERAL DE AJUSTES
            // =========================================================
            Container(
              width: 280,
              decoration: const BoxDecoration(
                color: Color(0xff111019),
                border: Border(right: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 28),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Ajustes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Configura tu experiencia en nubzzz',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // OPCIONES
                  ...List.generate(sections.length, (index) {
                    final item = sections[index];
                    final selected = selectedSection == index;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      child: Material(
                        color: selected
                            ? const Color(0xff6438FF)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              selectedSection = index;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            child: Row(
                              children: [
                                Icon(item.icon, color: Colors.white, size: 21),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: selected
                                              ? Colors.white70
                                              : Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  const Spacer(),

                  // VOLVER
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Volver'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white12),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // =========================================================
            // CONTENIDO
            // =========================================================
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (selectedSection) {
      case 0:
        return _buildAccountSettings();

      case 1:
        return _buildVoiceSettings();

      default:
        return const SizedBox.shrink();
    }
  }

  // =========================================================
  // CUENTA
  // =========================================================

  Widget _buildAccountSettings() {
    final user = _currentUser;

    final email = user?.email ?? 'No disponible';
    final userId = user?.id ?? 'No disponible';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cuenta',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Administra la información y seguridad de tu cuenta.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),

            const SizedBox(height: 35),

            // =====================================================
            // INFORMACIÓN DE LA CUENTA
            // =====================================================
            _settingsCard(
              icon: Icons.person_outline_rounded,
              title: 'Información de la cuenta',
              description: 'Correo electrónico, ID y datos de tu cuenta.',
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white38,
              ),
              onTap: () {
                _showAccountInformation(email: email, userId: userId);
              },
            ),

            const SizedBox(height: 14),

            // =====================================================
            // SEGURIDAD
            // =====================================================
            _settingsCard(
              icon: Icons.lock_outline_rounded,
              title: 'Seguridad',
              description: 'Cambia tu contraseña y administra la seguridad.',
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white38,
              ),
              onTap: () {
                _showSecurityOptions();
              },
            ),

            const SizedBox(height: 30),

            // =====================================================
            // INFORMACIÓN RÁPIDA
            // =====================================================
            const Text(
              'Información rápida',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xff211D2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                children: [
                  _infoRow(
                    icon: Icons.email_outlined,
                    title: 'Correo',
                    value: email,
                  ),

                  const Divider(color: Colors.white10, height: 25),

                  _infoRow(
                    icon: Icons.fingerprint_rounded,
                    title: 'ID de usuario',
                    value: userId,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // INFORMACIÓN DE CUENTA
  // =========================================================

  void _showAccountInformation({
    required String email,
    required String userId,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff211D2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.person_outline_rounded, color: Color(0xff9B7BFF)),
              SizedBox(width: 10),
              Text(
                'Información de la cuenta',
                style: TextStyle(color: Colors.white, fontSize: 19),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Correo electrónico',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),

              const SizedBox(height: 5),

              Text(
                email,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),

              const SizedBox(height: 20),

              const Text(
                'ID de usuario',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),

              const SizedBox(height: 5),

              SelectableText(
                userId,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Cerrar',
                style: TextStyle(color: Color(0xff9B7BFF)),
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // SEGURIDAD
  // =========================================================

  void _showSecurityOptions() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff211D2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: Color(0xff9B7BFF)),
              SizedBox(width: 10),
              Text(
                'Seguridad',
                style: TextStyle(color: Colors.white, fontSize: 19),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xff6438FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.password_rounded,
                    color: Color(0xff9B7BFF),
                  ),
                ),
                title: const Text(
                  'Cambiar contraseña',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Actualiza la contraseña de tu cuenta',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white38,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showChangePasswordDialog();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Cerrar',
                style: TextStyle(color: Color(0xff9B7BFF)),
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // CAMBIAR CONTRASEÑA
  // =========================================================

  void _showChangePasswordDialog() {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    bool obscurePassword = true;
    bool obscureConfirm = true;
    bool loading = false;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> changePassword() async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              if (passwordController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Las contraseñas no coinciden.'),
                  ),
                );
                return;
              }

              setDialogState(() {
                loading = true;
              });

              try {
                await _supabase.auth.updateUser(
                  UserAttributes(password: passwordController.text.trim()),
                );

                if (!dialogContext.mounted) return;

                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contraseña actualizada correctamente.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                setDialogState(() {
                  loading = false;
                });

                if (!dialogContext.mounted) return;

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text('No se pudo cambiar la contraseña: $e'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xff211D2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Row(
                children: [
                  Icon(Icons.lock_reset_rounded, color: Color(0xff9B7BFF)),
                  SizedBox(width: 10),
                  Text(
                    'Cambiar contraseña',
                    style: TextStyle(color: Colors.white, fontSize: 19),
                  ),
                ],
              ),
              content: SizedBox(
                width: 430,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Nueva contraseña',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        enabled: !loading,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Nueva contraseña',
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            color: Colors.white54,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setDialogState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white54,
                            ),
                          ),
                          filled: true,
                          fillColor: const Color(0xff17141f),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa una contraseña.';
                          }

                          if (value.length < 6) {
                            return 'Debe tener mínimo 6 caracteres.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Confirmar contraseña',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: confirmController,
                        obscureText: obscureConfirm,
                        enabled: !loading,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Repite la contraseña',
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            color: Colors.white54,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setDialogState(() {
                                obscureConfirm = !obscureConfirm;
                              });
                            },
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white54,
                            ),
                          ),
                          filled: true,
                          fillColor: const Color(0xff17141f),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Confirma tu contraseña.';
                          }

                          if (value != passwordController.text) {
                            return 'Las contraseñas no coinciden.';
                          }

                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),

                const SizedBox(width: 8),

                ElevatedButton(
                  onPressed: loading ? null : changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff6438FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Cambiar contraseña'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================
  // VOZ
  // =========================================================

  Widget _buildVoiceSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ajustes de voz',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Configura tu micrófono y experiencia de voz.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),

            const SizedBox(height: 35),

            _settingsCard(
              icon: Icons.mic_rounded,
              title: 'Micrófono',
              description: 'Selecciona el dispositivo que utilizará nubzzz.',
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white38,
              ),
            ),

            const SizedBox(height: 14),

            _settingsCard(
              icon: Icons.volume_up_rounded,
              title: 'Salida de audio',
              description: 'Selecciona dónde quieres escuchar el audio.',
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white38,
              ),
            ),

            const SizedBox(height: 14),

            _settingsCard(
              icon: Icons.graphic_eq_rounded,
              title: 'Prueba de micrófono',
              description:
                  'Comprueba que tu micrófono esté funcionando correctamente.',
              trailing: const Icon(
                Icons.play_circle_outline_rounded,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // TARJETA DE AJUSTES
  // =========================================================

  Widget _settingsCard({
    required IconData icon,
    required String title,
    required String description,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xff211D2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xff6438FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xff9B7BFF), size: 22),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              trailing,
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // FILA DE INFORMACIÓN
  // =========================================================

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xff9B7BFF), size: 21),

        const SizedBox(width: 14),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),

            const SizedBox(height: 3),

            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================
// MODELO DE OPCIÓN
// =============================================================

class _SettingsItem {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
