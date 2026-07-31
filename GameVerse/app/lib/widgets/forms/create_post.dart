import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/post_controller.dart';
import '../../services/post_service.dart';

class CreatePost extends StatefulWidget {
  final VoidCallback onPostCreated;

  const CreatePost({super.key, required this.onPostCreated});

  @override
  State<CreatePost> createState() => _CreatePostState();
}

class _CreatePostState extends State<CreatePost> {
  final TextEditingController controller = TextEditingController();

  final PostController postController = PostController.instance;
  final PostService postService = PostService();

  final ImagePicker picker = ImagePicker();

  Uint8List? selectedImageBytes;
  String? selectedImageName;

  Uint8List? selectedVideoBytes;
  String? selectedVideoName;

  bool loading = false;

  Future<void> pickImage() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    final bytes = await image.readAsBytes();

    setState(() {
      selectedImageBytes = bytes;
      selectedImageName = image.name;

      selectedVideoBytes = null;
      selectedVideoName = null;
    });
  }

  Future<void> pickVideo() async {
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video == null) return;

    final bytes = await video.readAsBytes();

    setState(() {
      selectedVideoBytes = bytes;
      selectedVideoName = video.name;

      selectedImageBytes = null;
      selectedImageName = null;
    });
  }

  void startStream() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Próximamente transmisiones 🔴")),
    );
  }

  void createPoll() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Próximamente encuestas 📊")));
  }

  Future<void> publishPost() async {
    if (controller.text.trim().isEmpty &&
        selectedImageBytes == null &&
        selectedVideoBytes == null) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      debugPrint("========== INICIO PUBLICACIÓN ==========");

      String? imageUrl;
      String? videoUrl;

      String type = "text";

      if (selectedImageBytes != null) {
        debugPrint("Subiendo imagen...");

        imageUrl = await postService.uploadImage(
          selectedImageBytes!,
          selectedImageName!,
        );

        debugPrint("Imagen subida:");
        debugPrint(imageUrl);

        type = "image";
      }

      if (selectedVideoBytes != null) {
        debugPrint("Subiendo video...");

        videoUrl = await postService.uploadVideo(
          selectedVideoBytes!,
          selectedVideoName!,
        );

        debugPrint("Video subido:");
        debugPrint(videoUrl);

        type = "video";
      }

      debugPrint("Creando publicación...");

      await postController.createPost(
        content: controller.text.trim(),
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        type: type,
      );

      debugPrint("Publicación creada correctamente.");

      controller.clear();

      setState(() {
        selectedImageBytes = null;
        selectedImageName = null;

        selectedVideoBytes = null;
        selectedVideoName = null;
      });

      widget.onPostCreated();

      debugPrint("========== FIN PUBLICACIÓN ==========");
    } catch (e, stackTrace) {
      debugPrint("====================================");
      debugPrint("ERROR AL PUBLICAR");
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());
      debugPrint("====================================");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              e.toString(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff211D2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "¿Qué estás jugando?",
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xff17141F),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (selectedImageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                selectedImageBytes!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

          if (selectedVideoBytes != null)
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 15,
                  children: [
                    TextButton.icon(
                      onPressed: pickImage,
                      icon: const Icon(Icons.image, color: Colors.greenAccent),
                      label: const Text(
                        "Imagen",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: pickVideo,
                      icon: const Icon(Icons.videocam, color: Colors.redAccent),
                      label: const Text(
                        "Video",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: startStream,
                      icon: const Icon(
                        Icons.wifi_tethering,
                        color: Colors.purpleAccent,
                      ),
                      label: const Text(
                        "Directo",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: createPoll,
                      icon: const Icon(Icons.poll, color: Colors.orangeAccent),
                      label: const Text(
                        "Encuesta",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),

              ElevatedButton(
                onPressed: loading ? null : publishPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff6438FF),
                ),
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Publicar",
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
