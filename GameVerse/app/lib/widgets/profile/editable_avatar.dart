import 'dart:typed_data';

import 'package:app/controllers/profile_controller.dart';
import 'package:app/services/image_picker_service.dart';
import 'package:app/services/image_storage_service.dart';
import 'package:flutter/material.dart';

class EditableAvatar extends StatefulWidget {
  const EditableAvatar({super.key});

  @override
  State<EditableAvatar> createState() => _EditableAvatarState();
}

class _EditableAvatarState extends State<EditableAvatar> {
  bool _hover = false;

  Uint8List? _avatarBytes;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final bytes = await ImageStorageService.loadAvatar();

    if (!mounted || bytes == null) return;

    // Actualiza el controlador global
    ProfileController().setAvatar(bytes);

    setState(() {
      _avatarBytes = bytes;
    });
  }

  Future<void> _pickAvatar() async {
    final bytes = await ImagePickerService.pickImage();

    if (bytes == null) return;

    // Guarda la imagen localmente
    await ImageStorageService.saveAvatar(bytes);

    // Actualiza el controlador global
    ProfileController().setAvatar(bytes);

    setState(() {
      _avatarBytes = bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _pickAvatar,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 5),
              ),
              child: CircleAvatar(
                radius: 60,
                backgroundImage: _avatarBytes != null
                    ? MemoryImage(_avatarBytes!)
                    : const AssetImage("assets/images/avatar.png")
                          as ImageProvider,
              ),
            ),

            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _hover ? 1 : 0,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .55),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _hover ? 1 : 0,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo_camera_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Cambiar\nfoto",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
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
  }
}
