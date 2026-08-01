import 'package:flutter/material.dart';

import '../../controllers/profile_controller.dart';

Future<void> showEditProfileDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const _EditProfileDialog(),
  );
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog();

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  final _profile = ProfileController.instance;
  late final TextEditingController _name;
  late final TextEditingController _handle;
  late final TextEditingController _motto;
  late final TextEditingController _bio;
  late final TextEditingController _location;
  late final TextEditingController _platform;
  late final TextEditingController _role;
  late final TextEditingController _favoriteGame;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _profile.username);
    _handle = TextEditingController(text: _profile.handle);
    _motto = TextEditingController(text: _profile.motto);
    _bio = TextEditingController(text: _profile.bio);
    _location = TextEditingController(text: _profile.location);
    _platform = TextEditingController(text: _profile.platform);
    _role = TextEditingController(text: _profile.role);
    _favoriteGame = TextEditingController(text: _profile.favoriteGame);
  }

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    _motto.dispose();
    _bio.dispose();
    _location.dispose();
    _platform.dispose();
    _role.dispose();
    _favoriteGame.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _profile.updateProfile(
        username: _name.text.trim(),
        handle: _handle.text.trim().replaceFirst(RegExp(r'^@'), ''),
        motto: _motto.text.trim(),
        bio: _bio.text.trim(),
        location: _location.text.trim(),
        platform: _platform.text.trim(),
        role: _role.text.trim(),
        favoriteGame: _favoriteGame.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el perfil: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1828),
        title: const Text('Editar perfil', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 580,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _field(_name, 'Nombre visible', required: true, maxLength: 30),
                _field(_handle, 'Usuario / handle', prefix: '@', maxLength: 24),
                _field(_motto, 'Lema', maxLength: 90),
                _field(_bio, 'Biografía', maxLines: 3, maxLength: 240),
                Row(children: [
                  Expanded(child: _field(_location, 'Ciudad o país', maxLength: 60)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_platform, 'Plataforma', hint: 'PC, PlayStation...', maxLength: 40)),
                ]),
                Row(children: [
                  Expanded(child: _field(_role, 'Rol gamer', hint: 'Support, streamer...', maxLength: 40)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_favoriteGame, 'Juego favorito', maxLength: 60)),
                ]),
                const Text('La foto y la portada se cambian directamente desde el perfil.', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D35F5), foregroundColor: Colors.white),
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Guardar cambios'),
          ),
        ],
      );

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    String? prefix,
    int maxLines = 1,
    int? maxLength,
    bool required = false,
  }) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          style: const TextStyle(color: Colors.white),
          validator: required
              ? (value) => value == null || value.trim().isEmpty ? 'Este campo es obligatorio.' : null
              : null,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixText: prefix,
            counterStyle: const TextStyle(color: Colors.white38),
            labelStyle: const TextStyle(color: Color(0xFFBDAAFF)),
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF39324F))),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
          ),
        ),
      );
}
