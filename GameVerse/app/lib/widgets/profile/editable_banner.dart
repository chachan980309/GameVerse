import 'dart:typed_data';

import 'package:app/services/image_picker_service.dart';
import 'package:app/services/image_storage_service.dart';
import 'package:flutter/material.dart';

class EditableBanner extends StatefulWidget {
  const EditableBanner({super.key});

  @override
  State<EditableBanner> createState() => _EditableBannerState();
}

class _EditableBannerState extends State<EditableBanner> {
  bool _hover = false;

  Uint8List? _bannerBytes;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  Future<void> _loadBanner() async {
    final bytes = await ImageStorageService.loadBanner();

    if (!mounted || bytes == null) return;

    setState(() {
      _bannerBytes = bytes;
    });
  }

  Future<void> _pickBanner() async {
    final bytes = await ImagePickerService.pickImage();

    if (bytes == null) return;

    await ImageStorageService.saveBanner(bytes);

    setState(() {
      _bannerBytes = bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _pickBanner,
        child: SizedBox(
          height: 220,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                child: _bannerBytes != null
                    ? Image.memory(_bannerBytes!, fit: BoxFit.cover)
                    : Image.asset(
                        "assets/images/banner.jpg",
                        fit: BoxFit.cover,
                      ),
              ),

              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: .15),
                        Colors.black.withValues(alpha: .70),
                      ],
                    ),
                  ),
                ),
              ),

              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _hover ? 1 : 0,
                child: Container(color: Colors.black.withValues(alpha: .25)),
              ),

              Positioned(
                top: 18,
                right: 18,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _hover ? 1 : 0,
                  child: ElevatedButton.icon(
                    onPressed: _pickBanner,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text("Cambiar banner"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff6E4CFF),
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
