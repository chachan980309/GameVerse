import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/post_controller.dart';
import '../../services/post_service.dart';

class CreatePost extends StatefulWidget {
  final VoidCallback onPostCreated;

  final bool compact;
  final String placeholder;

  const CreatePost({
    super.key,
    required this.onPostCreated,
    this.compact = false,
    this.placeholder = "¿Qué estás jugando?",
  });

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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.all(widget.compact ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xff211D2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xff6438FF),
                child: Icon(Icons.person, color: Colors.white),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: widget.compact ? 1 : 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: widget.placeholder,
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xff17141F),

                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),

                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),

                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(
                        color: Color(0xff6438FF),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: widget.compact ? 8 : 12),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: selectedImageBytes != null || selectedVideoBytes != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 10),
                    child: selectedImageBytes != null
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  selectedImageBytes!,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),

                              Positioned(
                                top: 8,
                                right: 8,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      setState(() {
                                        selectedImageBytes = null;
                                        selectedImageName = null;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Stack(
                            children: [
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

                              Positioned(
                                top: 8,
                                right: 8,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      setState(() {
                                        selectedVideoBytes = null;
                                        selectedVideoName = null;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  )
                : const SizedBox.shrink(),
          ),

          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 15,
                  children: [
                    widget.compact
                        ? IconButton(
                            tooltip: "Imagen",
                            onPressed: pickImage,
                            icon: const Icon(
                              Icons.image,
                              color: Colors.greenAccent,
                            ),
                          )
                        : TextButton.icon(
                            onPressed: pickImage,
                            icon: const Icon(
                              Icons.image,
                              color: Colors.greenAccent,
                            ),
                            label: const Text(
                              "Imagen",
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                    widget.compact
                        ? IconButton(
                            tooltip: "Video",
                            onPressed: pickVideo,
                            icon: const Icon(
                              Icons.videocam,
                              color: Colors.redAccent,
                            ),
                          )
                        : TextButton.icon(
                            onPressed: pickVideo,
                            icon: const Icon(
                              Icons.videocam,
                              color: Colors.redAccent,
                            ),
                            label: const Text(
                              "Video",
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                    widget.compact
                        ? IconButton(
                            tooltip: "Directo",
                            onPressed: startStream,
                            icon: const Icon(
                              Icons.wifi_tethering,
                              color: Colors.purpleAccent,
                            ),
                          )
                        : TextButton.icon(
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
                    widget.compact
                        ? IconButton(
                            tooltip: "Encuesta",
                            onPressed: createPoll,
                            icon: const Icon(
                              Icons.poll,
                              color: Colors.orangeAccent,
                            ),
                          )
                        : TextButton.icon(
                            onPressed: createPoll,
                            icon: const Icon(
                              Icons.poll,
                              color: Colors.orangeAccent,
                            ),
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
