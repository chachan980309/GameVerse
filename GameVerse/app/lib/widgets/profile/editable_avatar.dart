import 'package:app/controllers/profile_controller.dart';
import 'package:app/services/image_picker_service.dart';
import 'package:flutter/material.dart';

class EditableAvatar extends StatefulWidget {
  const EditableAvatar({super.key});

  @override
  State<EditableAvatar> createState() => _EditableAvatarState();
}

class _EditableAvatarState extends State<EditableAvatar> {
  bool _hover = false;

  final ProfileController profile = ProfileController();

  Future<void> _pickAvatar() async {
    try {
      debugPrint("========== INICIO CAMBIO AVATAR ==========");

      final bytes = await ImagePickerService.pickImage();

      if (bytes == null) {
        debugPrint("No se seleccionó ninguna imagen.");
        return;
      }

      debugPrint("Imagen seleccionada.");
      debugPrint("Tamaño: ${bytes.length} bytes");

      await profile.setAvatar(bytes);

      debugPrint("Avatar actualizado correctamente.");
      debugPrint("URL: ${profile.avatarUrl}");

      if (mounted) {
        setState(() {});
      }

      debugPrint("========== FIN CAMBIO AVATAR ==========");
    } catch (e, stack) {
      debugPrint("ERROR AL CAMBIAR AVATAR");
      debugPrint(e.toString());
      debugPrint(stack.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: profile,
      builder: (context, _) {
        return MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _pickAvatar,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ==========================
                // Avatar
                // ==========================
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xff6438FF),
                      width: 5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 85,

                    backgroundImage:
                        profile.avatarUrl != null &&
                            profile.avatarUrl!.isNotEmpty
                        ? NetworkImage(profile.avatarUrl!)
                        : const AssetImage("assets/images/avatar.png")
                              as ImageProvider,
                  ),
                ),

                // ==========================
                // Hover oscuro
                // ==========================
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _hover ? 1 : 0,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .55),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                // ==========================
                // Texto cambiar foto
                // ==========================
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _hover ? 1 : 0,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_camera_outlined,
                        color: Colors.white,
                        size: 30,
                      ),

                      SizedBox(height: 8),

                      Text(
                        "Cambiar\nfoto",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
