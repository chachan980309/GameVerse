import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/profile_controller.dart';
import '../services/audio_device_service.dart';
import '../services/auth_service.dart';
import '../services/sound_settings_service.dart';
import '../services/microphone_meter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ProfileController _profile = ProfileController.instance;
  final AuthService _authService = AuthService();

  int _selectedSection = 0;

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
  // INIT / DISPOSE
  // ============================================================

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

          _buildSettingCard(
            icon: Icons.person_outline,
            title: 'Nombre de usuario',
            subtitle: _profile.username,
            trailing: Icons.edit_outlined,
            onTap: _showUsernameDialog,
          ),

          const SizedBox(height: 14),

          _buildSettingCard(
            icon: Icons.badge_outlined,
            title: 'Información personal',
            subtitle: 'Nombre de usuario, perfil y datos personales.',
            onTap: _showPersonalInfoDialog,
          ),

          const SizedBox(height: 14),

          _buildSettingCard(
            icon: Icons.account_circle_outlined,
            title: 'Información de la cuenta',
            subtitle: 'Correo electrónico e identificador de tu cuenta.',
            onTap: () {
              _showAccountInfoDialog(user);
            },
          ),

          const SizedBox(height: 14),

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
  // USERNAME
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
              backgroundColor: card,
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
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
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
              backgroundColor: card,
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
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
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
          backgroundColor: card,
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
              backgroundColor: card,
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
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
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

          _buildSettingCard(
            icon: Icons.mic,
            title: 'Micrófono',
            subtitle: 'Selecciona y configura el dispositivo de entrada.',
            onTap: _showMicrophoneDialog,
          ),

          const SizedBox(height: 14),

          _buildSettingCard(
            icon: Icons.volume_up,
            title: 'Salida de audio',
            subtitle: 'Selecciona dónde quieres escuchar el audio.',
            onTap: _showOutputDialog,
          ),

          const SizedBox(height: 14),

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
      builder: (dialogContext) {
        Future<List<MediaDeviceInfo>> devicesFuture = _loadMicrophoneDevices();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.mic, color: purpleLight),
                  SizedBox(width: 10),
                  Text(
                    'Micrófono',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: FutureBuilder<List<MediaDeviceInfo>>(
                  future: devicesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 120,
                        child: Center(
                          child: CircularProgressIndicator(color: purpleLight),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return _buildMicrophoneError(
                        message: 'No se pudieron obtener los micrófonos.',
                        onRetry: () {
                          setDialogState(() {
                            devicesFuture = _loadMicrophoneDevices();
                          });
                        },
                      );
                    }

                    final devices = snapshot.data ?? [];

                    if (devices.isEmpty) {
                      return _buildMicrophoneError(
                        message: 'No se encontraron micrófonos disponibles.',
                        onRetry: () {
                          setDialogState(() {
                            devicesFuture = _loadMicrophoneDevices();
                          });
                        },
                      );
                    }

                    return FutureBuilder<String?>(
                      future: SoundSettingsService.getMicrophoneDeviceId(),
                      builder: (context, selectedSnapshot) {
                        final selectedId = selectedSnapshot.data;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selecciona tu dispositivo de entrada:',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 13,
                              ),
                            ),

                            const SizedBox(height: 16),

                            ...devices.map((device) {
                              return _buildMicrophoneOption(
                                dialogContext: dialogContext,
                                device: device,
                                selectedId: selectedId,
                                onSelected: () async {
                                  final deviceId = device.deviceId;

                                  if (deviceId.isEmpty) {
                                    return;
                                  }

                                  await SoundSettingsService.setMicrophoneDeviceId(
                                    deviceId,
                                  );

                                  if (!mounted) return;

                                  setDialogState(() {});

                                  _showMessage(
                                    'Micrófono seleccionado: ${_deviceLabel(device)}',
                                  );
                                },
                              );
                            }),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(color: purpleLight),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<MediaDeviceInfo>> _loadMicrophoneDevices() async {
    try {
      // Solicitamos permiso antes de enumerar los dispositivos.
      final stream = await AudioDeviceService.requestMicrophonePermission();

      if (stream != null) {
        await AudioDeviceService.stopStream(stream);
      }

      // Después del permiso obtenemos los dispositivos.
      return await AudioDeviceService.getInputDevices();
    } catch (e) {
      debugPrint('Error cargando micrófonos: $e');

      return [];
    }
  }

  Widget _buildMicrophoneError({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mic_off_outlined, color: Colors.white38, size: 44),

        const SizedBox(height: 14),

        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Verifica que tu micrófono esté conectado y que hayas permitido el acceso al micrófono en el navegador.',
          textAlign: TextAlign.center,
          style: TextStyle(color: textSecondary, fontSize: 12),
        ),

        const SizedBox(height: 20),

        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Volver a buscar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: purple,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildMicrophoneOption({
    required BuildContext dialogContext,
    required MediaDeviceInfo device,
    required String? selectedId,
    required VoidCallback onSelected,
  }) {
    final deviceId = device.deviceId;

    final selected = selectedId == deviceId;

    final label = _deviceLabel(device);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: deviceId.isEmpty ? null : onSelected,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? const Color(0xff33235d) : const Color(0xff17141f),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? purpleLight : const Color(0xff302b3d),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? purpleLight : Colors.white54,
            ),

            const SizedBox(width: 12),

            const Icon(Icons.mic, color: Colors.white70, size: 20),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),

            if (selected) const Icon(Icons.check, color: purpleLight, size: 20),
          ],
        ),
      ),
    );
  }

  String _deviceLabel(MediaDeviceInfo device) {
    final label = device.label.trim();

    if (label.isNotEmpty) {
      return label;
    }

    return 'Micrófono disponible';
  }

  // ============================================================
  // SALIDA DE AUDIO
  // ============================================================

  void _showOutputDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        Future<List<MediaDeviceInfo>> devicesFuture =
            AudioDeviceService.getOutputDevices();

        String? selectedDeviceId;
        bool initializedSelection = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.volume_up, color: purpleLight),
                  SizedBox(width: 10),
                  Text(
                    'Salida de audio',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: FutureBuilder<List<MediaDeviceInfo>>(
                  future: devicesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 120,
                        child: Center(
                          child: CircularProgressIndicator(color: purpleLight),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.volume_off_outlined,
                            color: Colors.white38,
                            size: 44,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No se pudieron obtener los dispositivos de salida.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                devicesFuture =
                                    AudioDeviceService.getOutputDevices();
                              });
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Volver a buscar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purple,
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                          ),
                        ],
                      );
                    }

                    final devices = snapshot.data ?? [];

                    if (devices.isEmpty) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.volume_off_outlined,
                            color: Colors.white38,
                            size: 44,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No se encontraron dispositivos de salida de audio.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                devicesFuture =
                                    AudioDeviceService.getOutputDevices();
                              });
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Volver a buscar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purple,
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                          ),
                        ],
                      );
                    }

                    if (!initializedSelection) {
                      initializedSelection = true;

                      SoundSettingsService.getOutputDeviceId().then((savedId) {
                        if (!mounted) return;

                        final exists =
                            savedId != null &&
                            devices.any((device) => device.deviceId == savedId);

                        setDialogState(() {
                          selectedDeviceId = exists ? savedId : null;
                        });
                      });
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selecciona dónde quieres escuchar el audio:',
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ...devices.map((device) {
                          final deviceId = device.deviceId;
                          final label = _outputDeviceLabel(device);
                          final selected = selectedDeviceId == deviceId;

                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: deviceId.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() {
                                      selectedDeviceId = deviceId;
                                    });

                                    await SoundSettingsService.setOutputDeviceId(
                                      deviceId,
                                    );

                                    if (!mounted) return;

                                    _showMessage(
                                      'Salida de audio seleccionada: $label',
                                    );
                                  },
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xff33235d)
                                    : const Color(0xff17141f),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? purpleLight
                                      : const Color(0xff302b3d),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: selected
                                        ? purpleLight
                                        : Colors.white54,
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.volume_up,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      label,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (selected)
                                    const Icon(
                                      Icons.check,
                                      color: purpleLight,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(color: purpleLight),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _outputDeviceLabel(MediaDeviceInfo device) {
    final label = device.label.trim();

    if (label.isNotEmpty) {
      return label;
    }

    return 'Dispositivo de salida disponible';
  }

  // ============================================================
  // PRUEBA DE MICRÓFONO
  // ============================================================

  void _showMicrophoneTest() {
    MediaStream? microphoneStream;
    final meter = MicrophoneMeter();

    bool running = false;
    bool loading = false;
    double level = 0.0;
    String? errorMessage;

    Future<void> stopTest(void Function(void Function()) setDialogState) async {
      try {
        await meter.stop();
      } catch (_) {}

      final stream = microphoneStream;
      microphoneStream = null;

      if (stream != null) {
        await AudioDeviceService.stopStream(stream);
      }

      setDialogState(() {
        running = false;
        loading = false;
        level = 0.0;
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> startTest() async {
              if (running || loading) return;

              setDialogState(() {
                loading = true;
                errorMessage = null;
                level = 0.0;
              });

              try {
                final savedDeviceId =
                    await SoundSettingsService.getMicrophoneDeviceId();

                MediaStream? stream;

                if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
                  stream = await AudioDeviceService.openMicrophone(
                    savedDeviceId,
                  );
                }

                // Si no hay un micrófono guardado o no se pudo abrir,
                // usamos el dispositivo de entrada predeterminado.
                stream ??=
                    await AudioDeviceService.requestMicrophonePermission();

                if (stream == null) {
                  throw Exception('No se pudo acceder al micrófono.');
                }

                microphoneStream = stream;

                await meter.start(stream, (value) {
                  if (!context.mounted) return;

                  setDialogState(() {
                    level = value.clamp(0.0, 1.0);
                  });
                });

                if (!context.mounted) return;

                setDialogState(() {
                  loading = false;
                  running = true;
                });
              } catch (e) {
                await meter.stop();

                final stream = microphoneStream;
                microphoneStream = null;

                if (stream != null) {
                  await AudioDeviceService.stopStream(stream);
                }

                if (!context.mounted) return;

                setDialogState(() {
                  loading = false;
                  running = false;
                  level = 0.0;
                  errorMessage = 'No se pudo iniciar la prueba del micrófono.';
                });
              }
            }

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
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Habla para comprobar el nivel de entrada de tu micrófono.',
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      height: 18,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xff17141f),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: const Color(0xff302b3d)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: level,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xff743cff),
                                    Color(0xff9b6cff),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          running
                              ? 'Micrófono activo'
                              : loading
                              ? 'Iniciando...'
                              : 'Micrófono detenido',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${(level * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xff3a1d2b),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xff65304a)),
                        ),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (running) {
                            await stopTest(setDialogState);
                          }

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(color: purpleLight),
                  ),
                ),
                if (!running)
                  ElevatedButton.icon(
                    onPressed: loading ? null : startTest,
                    icon: loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.mic),
                    label: Text(loading ? 'Iniciando...' : 'Iniciar prueba'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () => stopTest(setDialogState),
                    icon: const Icon(Icons.stop),
                    label: const Text('Detener'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff3a3348),
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
              ],
            );
          },
        );
      },
    ).then((_) async {
      try {
        await meter.stop();
      } catch (_) {}

      final stream = microphoneStream;
      microphoneStream = null;

      if (stream != null) {
        await AudioDeviceService.stopStream(stream);
      }
    });
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
