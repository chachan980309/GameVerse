import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/profile_controller.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ProfileController _profile = ProfileController.instance;
  final AuthService _authService = AuthService();

  int _selectedSection = 0;

  @override
  void initState() {
    super.initState();

    _profile.addListener(_profileChanged);
  }

  @override
  void dispose() {
    _profile.removeListener(_profileChanged);
    super.dispose();
  }

  void _profileChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // COLORES
  // ============================================================

  static const Color background = Color(0xff15121d);
  static const Color sidebar = Color(0xff100e16);
  static const Color card = Color(0xff211d2e);
  static const Color cardHover = Color(0xff272237);
  static const Color purple = Color(0xff743cff);
  static const Color purpleLight = Color(0xff9b6cff);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xffa29dab);

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  // ============================================================
  // SIDEBAR
  // ============================================================

  Widget _buildSidebar() {
    return Container(
      width: 270,
      decoration: const BoxDecoration(
        color: sidebar,
        border: Border(right: BorderSide(color: Color(0xff292532), width: 1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Ajustes',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 10),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Configura tu experiencia en nubzzz',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
            ),

            const SizedBox(height: 38),

            _buildSidebarItem(
              index: 0,
              icon: Icons.person,
              title: 'Cuenta',
              subtitle: 'Configuración de tu cuenta',
            ),

            const SizedBox(height: 8),

            _buildSidebarItem(
              index: 1,
              icon: Icons.mic,
              title: 'Ajustes de voz',
              subtitle: 'Micrófono, entrada y configuración ...',
            ),

            const Spacer(),

            // VOLVER
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xff302b3b)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back, size: 17, color: textSecondary),
                    SizedBox(width: 8),
                    Text(
                      'Volver',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _selectedSection == index;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _selectedSection = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? purple : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white70 : textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONTENIDO
  // ============================================================

  Widget _buildContent() {
    if (_selectedSection == 1) {
      return _buildVoiceSettings();
    }

    return _buildAccountSettings();
  }

  // ============================================================
  // CUENTA
  // ============================================================

  Widget _buildAccountSettings() {
    final user = Supabase.instance.client.auth.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 42, 40, 60),
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
            style: TextStyle(color: textSecondary, fontSize: 14),
          ),

          const SizedBox(height: 34),

          // ====================================================
          // NOMBRE DE USUARIO
          // ====================================================
          _buildSettingCard(
            icon: Icons.person_outline,
            title: 'Nombre de usuario',
            subtitle: _profile.username,
            trailing: Icons.edit_outlined,
            onTap: _showUsernameDialog,
          ),

          const SizedBox(height: 14),

          // ====================================================
          // INFORMACIÓN PERSONAL
          // ====================================================
          _buildSettingCard(
            icon: Icons.badge_outlined,
            title: 'Información personal',
            subtitle: 'Nombre de usuario, perfil y datos personales.',
            onTap: _showPersonalInfoDialog,
          ),

          const SizedBox(height: 14),

          // ====================================================
          // INFORMACIÓN DE CUENTA
          // ====================================================
          _buildSettingCard(
            icon: Icons.account_circle_outlined,
            title: 'Información de la cuenta',
            subtitle: 'Correo electrónico e identificador de tu cuenta.',
            onTap: () {
              _showAccountInfoDialog(user);
            },
          ),

          const SizedBox(height: 14),

          // ====================================================
          // SEGURIDAD
          // ====================================================
          _buildSettingCard(
            icon: Icons.lock_outline,
            title: 'Seguridad',
            subtitle: 'Cambia tu contraseña y administra la seguridad.',
            onTap: _showSecurityDialog,
          ),

          const SizedBox(height: 32),

          const Text(
            'Información rápida',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 14),

          _buildQuickInfo(user),
        ],
      ),
    );
  }

  // ============================================================
  // CARD
  // ============================================================

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    IconData? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        hoverColor: cardHover,
        child: Container(
          width: double.infinity,
          height: 84,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xff302b3d)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xff33235d),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: purpleLight, size: 23),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                trailing ?? Icons.chevron_right,
                color: trailing != null ? purpleLight : Colors.white54,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INFORMACIÓN RÁPIDA
  // ============================================================

  Widget _buildQuickInfo(User? user) {
    final email = user?.email ?? 'No disponible';
    final id = user?.id ?? 'No disponible';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xff302b3d)),
      ),
      child: Column(
        children: [
          _buildQuickInfoRow(
            icon: Icons.email_outlined,
            title: 'Correo',
            value: email,
          ),

          const Divider(color: Color(0xff302b3d), height: 24),

          _buildQuickInfoRow(
            icon: Icons.fingerprint,
            title: 'ID de usuario',
            value: id,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: purpleLight, size: 21),

        const SizedBox(width: 16),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: textSecondary, fontSize: 11),
            ),

            const SizedBox(height: 4),

            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // CAMBIAR USERNAME
  // ============================================================

  void _showUsernameDialog() {
    final controller = TextEditingController(text: _profile.username);

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xff211d2e),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.person_outline, color: purpleLight),
                  SizedBox(width: 10),
                  Text(
                    'Cambiar nombre de usuario',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: TextField(
                  controller: controller,
                  maxLength: 30,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person, color: Colors.white54),
                    hintText: 'Nombre de usuario',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xff17141f),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final username = controller.text.trim();

                          if (username.isEmpty) {
                            _showMessage(
                              'El nombre de usuario no puede estar vacío.',
                            );
                            return;
                          }

                          if (username.length < 3) {
                            _showMessage(
                              'El nombre debe tener al menos 3 caracteres.',
                            );
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                          });

                          try {
                            await _profile.updateProfile(username: username);

                            if (!mounted) return;

                            Navigator.pop(dialogContext);

                            _showMessage('Nombre de usuario actualizado.');
                          } catch (e) {
                            setDialogState(() {
                              saving = false;
                            });

                            _showMessage('No se pudo actualizar el nombre.');
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // INFORMACIÓN PERSONAL
  // ============================================================

  void _showPersonalInfoDialog() {
    final bioController = TextEditingController(text: _profile.bio);

    final handleController = TextEditingController(text: _profile.handle);

    final mottoController = TextEditingController(text: _profile.motto);

    final locationController = TextEditingController(text: _profile.location);

    final platformController = TextEditingController(text: _profile.platform);

    final roleController = TextEditingController(text: _profile.role);

    final favoriteGameController = TextEditingController(
      text: _profile.favoriteGame,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xff211d2e),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.badge_outlined, color: purpleLight),
                  SizedBox(width: 10),
                  Text(
                    'Información personal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildDialogField(
                        controller: bioController,
                        label: 'Biografía',
                        hint: 'Cuéntale algo a la comunidad...',
                        icon: Icons.description_outlined,
                        maxLines: 3,
                      ),

                      const SizedBox(height: 12),

                      _buildDialogField(
                        controller: handleController,
                        label: 'Usuario / Handle',
                        hint: '@usuario',
                        icon: Icons.alternate_email,
                      ),

                      const SizedBox(height: 12),

                      _buildDialogField(
                        controller: mottoController,
                        label: 'Frase',
                        hint: 'Tu frase personal',
                        icon: Icons.auto_awesome_outlined,
                      ),

                      const SizedBox(height: 12),

                      _buildDialogField(
                        controller: locationController,
                        label: 'Ubicación',
                        hint: '¿De dónde eres?',
                        icon: Icons.location_on_outlined,
                      ),

                      const SizedBox(height: 12),

                      _buildDialogField(
                        controller: platformController,
                        label: 'Plataforma',
                        hint: 'PC, PlayStation, Xbox...',
                        icon: Icons.devices_outlined,
                      ),

                      const SizedBox(height: 12),

                      _buildDialogField(
                        controller: roleController,
                        label: 'Rol',
                        hint: 'Jugador, creador, streamer...',
                        icon: Icons.workspace_premium_outlined,
                      ),

                      const SizedBox(height: 12),

                      _buildDialogField(
                        controller: favoriteGameController,
                        label: 'Juego favorito',
                        hint: '¿Cuál es tu juego favorito?',
                        icon: Icons.sports_esports_outlined,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setDialogState(() {
                            saving = true;
                          });

                          try {
                            await _profile.updateProfile(
                              bio: bioController.text.trim(),
                              handle: handleController.text.trim(),
                              motto: mottoController.text.trim(),
                              location: locationController.text.trim(),
                              platform: platformController.text.trim(),
                              role: roleController.text.trim(),
                              favoriteGame: favoriteGameController.text.trim(),
                            );

                            if (!mounted) return;

                            Navigator.pop(dialogContext);

                            _showMessage('Información personal actualizada.');
                          } catch (e) {
                            setDialogState(() {
                              saving = false;
                            });

                            _showMessage(
                              'No se pudo actualizar la información.',
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Guardar cambios'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: purpleLight),
        hintStyle: const TextStyle(color: Colors.white30),
        prefixIcon: Icon(icon, color: purpleLight),
        filled: true,
        fillColor: const Color(0xff17141f),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: purpleLight),
        ),
      ),
    );
  }

  // ============================================================
  // INFORMACIÓN DE CUENTA
  // ============================================================

  void _showAccountInfoDialog(User? user) {
    final email = user?.email ?? 'No disponible';
    final id = user?.id ?? 'No disponible';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xff211d2e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.account_circle_outlined, color: purpleLight),
              SizedBox(width: 10),
              Text(
                'Información de la cuenta',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAccountDetail(
                  Icons.email_outlined,
                  'Correo electrónico',
                  email,
                ),

                const SizedBox(height: 14),

                _buildAccountDetail(Icons.fingerprint, 'ID de usuario', id),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cerrar', style: TextStyle(color: purpleLight)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccountDetail(IconData icon, String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff17141f),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: purpleLight),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: textSecondary, fontSize: 11),
                ),

                const SizedBox(height: 4),

                SelectableText(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEGURIDAD
  // ============================================================

  void _showSecurityDialog() {
    final passwordController = TextEditingController();

    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool saving = false;
        bool obscurePassword = true;
        bool obscureConfirm = true;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xff211d2e),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.lock_outline, color: purpleLight),
                  SizedBox(width: 10),
                  Text(
                    'Seguridad',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 430,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Cambia la contraseña de tu cuenta.',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: purpleLight,
                        ),
                        hintText: 'Nueva contraseña',
                        hintStyle: const TextStyle(color: Colors.white38),
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
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: confirmController,
                      obscureText: obscureConfirm,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: purpleLight,
                        ),
                        hintText: 'Confirmar contraseña',
                        hintStyle: const TextStyle(color: Colors.white38),
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
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '• Mínimo 6 caracteres',
                        style: TextStyle(color: textSecondary, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final password = passwordController.text;

                          final confirm = confirmController.text;

                          if (password.length < 6) {
                            _showMessage(
                              'La contraseña debe tener al menos 6 caracteres.',
                            );
                            return;
                          }

                          if (password != confirm) {
                            _showMessage('Las contraseñas no coinciden.');
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                          });

                          try {
                            await Supabase.instance.client.auth.updateUser(
                              UserAttributes(password: password),
                            );

                            if (!mounted) return;

                            Navigator.pop(dialogContext);

                            _showMessage(
                              'Contraseña actualizada correctamente.',
                            );
                          } catch (e) {
                            setDialogState(() {
                              saving = false;
                            });

                            _showMessage(
                              'No se pudo actualizar la contraseña.',
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: saving
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

  // ============================================================
  // AJUSTES DE VOZ
  // ============================================================

  Widget _buildVoiceSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 42, 40, 60),
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
            'Configura tu micrófono y salida de audio.',
            style: TextStyle(color: textSecondary, fontSize: 14),
          ),

          const SizedBox(height: 34),

          // MICRÓFONO
          _buildSettingCard(
            icon: Icons.mic,
            title: 'Micrófono',
            subtitle: 'Selecciona y configura el dispositivo de entrada.',
            onTap: _showMicrophoneDialog,
          ),

          const SizedBox(height: 14),

          // SALIDA
          _buildSettingCard(
            icon: Icons.volume_up,
            title: 'Salida de audio',
            subtitle: 'Selecciona dónde quieres escuchar el audio.',
            onTap: _showOutputDialog,
          ),

          const SizedBox(height: 14),

          // PRUEBA
          _buildSettingCard(
            icon: Icons.graphic_eq,
            title: 'Prueba de micrófono',
            subtitle:
                'Comprueba que tu micrófono esté funcionando correctamente.',
            trailing: Icons.play_circle_outline,
            onTap: _showMicrophoneTest,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MICRÓFONO
  // ============================================================

  void _showMicrophoneDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Micrófono', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Aquí podrás seleccionar el dispositivo de entrada de audio disponible en tu equipo.',
            style: TextStyle(color: textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cerrar', style: TextStyle(color: purpleLight)),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // SALIDA DE AUDIO
  // ============================================================

  void _showOutputDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Salida de audio',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Aquí podrás seleccionar dónde quieres escuchar el audio.',
            style: TextStyle(color: textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cerrar', style: TextStyle(color: purpleLight)),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // PRUEBA DE MICRÓFONO
  // ============================================================

  void _showMicrophoneTest() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.graphic_eq, color: purpleLight),
              SizedBox(width: 10),
              Text(
                'Prueba de micrófono',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: const SizedBox(
            width: 420,
            child: Text(
              'La prueba de micrófono se encuentra disponible desde la configuración de audio.',
              style: TextStyle(color: textSecondary),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cerrar', style: TextStyle(color: purpleLight)),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // MENSAJE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xff29233a),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
