import 'package:flutter/material.dart';

import 'package:app/controllers/profile_controller.dart';
import 'package:app/services/image_picker_service.dart';

class EditableBanner extends StatefulWidget {
  const EditableBanner({super.key});

  @override
  State<EditableBanner> createState() => _EditableBannerState();
}

class _EditableBannerState extends State<EditableBanner> {
  final ProfileController _profile = ProfileController();
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _profile.addListener(_refresh);
  }

  @override
  void dispose() {
    _profile.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _pickBanner() async {
    final bytes = await ImagePickerService.pickImage();
    if (bytes == null) return;

    // La imagen se usa directamente como portada: sin recorte manual,
    // imagen contenida ni fondo borroso de relleno.
    await _profile.setBanner(bytes, verticalPosition: 0);
  }

  @override
  Widget build(BuildContext context) {
    final image = _profile.bannerUrl != null && _profile.bannerUrl!.isNotEmpty
        ? NetworkImage(_profile.bannerUrl!) as ImageProvider
        : const AssetImage('assets/images/banner.jpg');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _pickBanner,
        child: SizedBox(
          width: double.infinity,
          height: 210,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image(
                image: image,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: .08),
                      Colors.black.withValues(alpha: .60),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _hover ? 1 : 0,
                  child: ElevatedButton.icon(
                    onPressed: _pickBanner,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Cambiar banner'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff6E4CFF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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
      ),
    );
  }
}
