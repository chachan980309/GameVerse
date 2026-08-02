import 'dart:typed_data';
import 'dart:ui';

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
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickBanner() async {
    final bytes = await ImagePickerService.pickImage();

    if (bytes == null) return;

    if (!mounted) return;
    final verticalPosition = await _showPreview(bytes);
    if (verticalPosition == null) return;

    await _profile.setBanner(
      bytes,
      verticalPosition: verticalPosition,
    );
  }

  Future<double?> _showPreview(Uint8List bytes) {
    var position = _profile.bannerPosition;

    return showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1B1828),
          title: const Text(
            'Ajustar banner',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 620,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 6.6,
                    child: _adaptiveBanner(
                      MemoryImage(bytes),
                      alignment: Alignment(0, position),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Las fotos cuadradas o verticales se conservan completas; '
                  'el fondo se adapta automáticamente.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Posición vertical',
                  style: TextStyle(color: Colors.white70),
                ),
                Slider(
                  value: position,
                  min: -1,
                  max: 1,
                  divisions: 100,
                  label: position < -.33
                      ? 'Arriba'
                      : position > .33
                      ? 'Abajo'
                      : 'Centro',
                  activeColor: const Color(0xFF8B5CF6),
                  onChanged: (value) => setDialogState(() => position = value),
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Arriba', style: TextStyle(color: Colors.white54)),
                    Text('Centro', style: TextStyle(color: Colors.white54)),
                    Text('Abajo', style: TextStyle(color: Colors.white54)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, position),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D35F5),
                foregroundColor: Colors.white,
              ),
              child: const Text('Usar banner'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adaptiveBanner(
    ImageProvider image, {
    required Alignment alignment,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Image(
            image: image,
            fit: BoxFit.cover,
            alignment: alignment,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
          ),
        ),
        const ColoredBox(color: Color(0x88000000)),
        Image(
          image: image,
          fit: BoxFit.contain,
          alignment: alignment,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
              // Imagen del banner
              _adaptiveBanner(
                _profile.bannerUrl != null && _profile.bannerUrl!.isNotEmpty
                    ? NetworkImage(_profile.bannerUrl!)
                    : const AssetImage("assets/images/banner.jpg"),
                alignment: Alignment(0, _profile.bannerPosition),
              ),

              // Degradado
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: .12),
                      Colors.black.withValues(alpha: .72),
                    ],
                  ),
                ),
              ),

              // Oscurecer al pasar el mouse
              AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _hover ? 1 : 0,
                child: Container(color: Colors.black.withValues(alpha: .25)),
              ),

              // Botón cambiar banner
              Positioned(
                top: 16,
                right: 16,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _hover ? 1 : 0,
                  child: ElevatedButton.icon(
                    onPressed: _pickBanner,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text("Cambiar banner"),
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
