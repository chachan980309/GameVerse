import 'dart:typed_data';

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
    if (bytes == null || !mounted) return;

    final framing = await _showPreview(bytes);
    if (framing == null) return;

    try {
      await _profile.setBanner(
        bytes,
        verticalPosition: framing.verticalPosition,
        scale: framing.scale,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el banner: $error')),
      );
    }
  }

  Future<_BannerFraming?> _showPreview(Uint8List bytes) {
    var verticalPosition = _profile.bannerPosition;
    var scale = _profile.bannerScale;

    return showDialog<_BannerFraming>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1B1828),
          title: const Text(
            'Ajustar banner',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 650,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 6.6,
                    child: _bannerImage(
                      MemoryImage(bytes),
                      verticalPosition: verticalPosition,
                      scale: scale,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Subir / bajar', style: TextStyle(color: Colors.white70)),
                Slider(
                  value: verticalPosition,
                  min: -1,
                  max: 1,
                  divisions: 100,
                  activeColor: const Color(0xFF8B5CF6),
                  onChanged: (value) => setDialogState(
                    () => verticalPosition = value,
                  ),
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Arriba', style: TextStyle(color: Colors.white54)),
                    Text('Centro', style: TextStyle(color: Colors.white54)),
                    Text('Abajo', style: TextStyle(color: Colors.white54)),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Acercar / alejar', style: TextStyle(color: Colors.white70)),
                Slider(
                  value: scale,
                  min: 1,
                  max: 2.4,
                  divisions: 70,
                  label: '${scale.toStringAsFixed(1)}x',
                  activeColor: const Color(0xFF8B5CF6),
                  onChanged: (value) => setDialogState(() => scale = value),
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Alejar', style: TextStyle(color: Colors.white54)),
                    Text('Acercar', style: TextStyle(color: Colors.white54)),
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
              onPressed: () => Navigator.pop(
                context,
                _BannerFraming(verticalPosition, scale),
              ),
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

  Widget _bannerImage(
    ImageProvider image, {
    required double verticalPosition,
    required double scale,
  }) {
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        alignment: Alignment(0, verticalPosition),
        child: Image(
          image: image,
          fit: BoxFit.cover,
          alignment: Alignment(0, verticalPosition),
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
        ),
      ),
    );
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
              _bannerImage(
                image,
                verticalPosition: _profile.bannerPosition,
                scale: _profile.bannerScale,
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
                      backgroundColor: const Color(0xFF6E4CFF),
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

class _BannerFraming {
  const _BannerFraming(this.verticalPosition, this.scale);

  final double verticalPosition;
  final double scale;
}
