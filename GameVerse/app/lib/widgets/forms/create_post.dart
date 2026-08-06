import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/post_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../services/post_service.dart';
import '../../services/mention_service.dart';
import '../../services/live_stream_service.dart';
import '../../pages/live_stream_page.dart';
import '../../utils/video_metadata_helper.dart';

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
  final MentionService _mentionService = MentionService();
  Timer? _mentionDebounce;
  List<Map<String, dynamic>> _mentionSuggestions = [];
  int? _mentionStart;
  bool _searchingMentions = false;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final selection = controller.selection;
    final cursor = selection.baseOffset;
    if (cursor < 0) return;
    final beforeCursor = controller.text.substring(0, cursor);
    final match = RegExp(r'@([A-Za-z0-9_.-]*)$').firstMatch(beforeCursor);
    _mentionDebounce?.cancel();
    if (match == null) {
      if (_mentionSuggestions.isNotEmpty || _searchingMentions) {
        setState(() {
          _mentionSuggestions = [];
          _searchingMentions = false;
          _mentionStart = null;
        });
      }
      return;
    }
    _mentionStart = match.start;
    final query = match.group(1) ?? '';
    if (query.isEmpty) {
      setState(() {
        _mentionSuggestions = [];
        _searchingMentions = false;
      });
      return;
    }
    setState(() => _searchingMentions = true);
    _mentionDebounce = Timer(
      const Duration(milliseconds: 250),
      () => _searchMentions(query),
    );
  }

  Future<void> _searchMentions(String query) async {
    try {
      final users = await _mentionService.searchUsers(query);
      if (!mounted ||
          !controller.text
              .substring(0, controller.selection.baseOffset)
              .endsWith(query)) {
        return;
      }
      setState(() => _mentionSuggestions = users);
    } catch (_) {
      if (mounted) setState(() => _mentionSuggestions = []);
    } finally {
      if (mounted) setState(() => _searchingMentions = false);
    }
  }

  void _insertMention(Map<String, dynamic> user) {
    final start = _mentionStart;
    final cursor = controller.selection.baseOffset;
    final username = user['username']?.toString() ?? '';
    if (start == null || cursor < start || username.isEmpty) return;
    final updated =
        '${controller.text.substring(0, start)}@$username ${controller.text.substring(cursor)}';
    final newOffset = start + username.length + 2;
    controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    setState(() {
      _mentionSuggestions = [];
      _mentionStart = null;
    });
  }

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

  Future<void> startStream() async {
    final titleController = TextEditingController(
      text: controller.text.trim(),
    );
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff191525),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Iniciar directo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Transmite tu pantalla en tiempo real. Tus seguidores podrán verlo en el feed.',
              style: TextStyle(color: Color(0xffA39DAD), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              autofocus: true,
              maxLength: 80,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Título del directo',
                hintText: 'Ej. Jugando Valorant ranked',
                labelStyle: const TextStyle(color: Color(0xffBFA8E8)),
                hintStyle: const TextStyle(color: Color(0xff777383)),
                counterStyle: const TextStyle(color: Color(0xff777383)),
                filled: true,
                fillColor: const Color(0xff100D1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: Color(0xff49306B)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: Color(0xff49306B)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(
                    color: Color(0xff8B4DFF),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              final t = titleController.text.trim();
              if (t.isNotEmpty) Navigator.pop(ctx, t);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffD9485F),
            ),
            icon: const Icon(Icons.wifi_tethering_rounded),
            label: const Text('Ir en directo'),
          ),
        ],
      ),
    );
    titleController.dispose();
    if (title == null || !mounted) return;

    setState(() => loading = true);
    try {
      final liveService = LiveStreamService();
      final roomName =
          'live-${Supabase.instance.client.auth.currentUser!.id.substring(0, 8)}-${DateTime.now().millisecondsSinceEpoch}';

      final stream = await liveService.startLiveStream(
        title: title,
        roomName: roomName,
      );

      await postController.createPost(
        content: title,
        type: 'live',
        streamId: stream['id'] as String,
      );

      controller.clear();
      widget.onPostCreated();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveStreamPage(
            streamId: stream['id'] as String,
            roomName: roomName,
            title: title,
            isHost: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('No se pudo iniciar el directo: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
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

      String? duration;
      String? thumbnailUrl;
      int? videoWidth;
      int? videoHeight;
      double? videoAspectRatio;

      if (selectedVideoBytes != null) {
        debugPrint("Iniciando subidas de video y miniatura en paralelo...");
        type = "video";

        // Lanzar ambas tareas asíncronas en paralelo para optimizar el rendimiento y no bloquear la subida
        final uploadTasks = await Future.wait([
          postService.uploadVideo(selectedVideoBytes!, selectedVideoName!),
          Future(() async {
            try {
              debugPrint("Extrayendo metadatos y miniatura del video...");
              final meta = await VideoMetadataHelper.extractMetadata(selectedVideoBytes!, selectedVideoName!);
              final durationVal = meta['duration'] as String?;
              final thumbBytes = meta['thumbnailBytes'] as Uint8List?;
              final w = meta['width'] as int?;
              final h = meta['height'] as int?;
              final ratio = meta['aspectRatio'] as double?;
              
              String? thumbUrl;
              if (thumbBytes != null) {
                debugPrint("Subiendo miniatura generada...");
                thumbUrl = await postService.uploadThumbnail(
                  thumbBytes,
                  "thumb_${DateTime.now().millisecondsSinceEpoch}.jpg",
                );
                debugPrint("Miniatura subida: $thumbUrl");
              }
              return {
                'duration': durationVal,
                'thumbnailUrl': thumbUrl,
                'width': w,
                'height': h,
                'aspectRatio': ratio,
              };
            } catch (e) {
              debugPrint("Error al extraer miniatura o duración del video: $e");
              return <String, dynamic>{};
            }
          }),
        ]);

        videoUrl = uploadTasks[0] as String;
        final metaResults = uploadTasks[1] as Map<String, dynamic>;
        duration = metaResults['duration'] as String?;
        thumbnailUrl = metaResults['thumbnailUrl'] as String?;
        videoWidth = metaResults['width'] as int?;
        videoHeight = metaResults['height'] as int?;
        videoAspectRatio = metaResults['aspectRatio'] as double?;

        debugPrint("Video subido: $videoUrl");
        debugPrint("Miniatura subida: $thumbnailUrl");
        debugPrint("Duración: $duration");
        debugPrint("Dimensiones: $videoWidth x $videoHeight (aspectRatio: $videoAspectRatio)");
      }

      debugPrint("Creando publicación...");

      await postController.createPost(
        content: controller.text.trim(),
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        duration: duration,
        width: videoWidth,
        height: videoHeight,
        aspectRatio: videoAspectRatio,
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
    _mentionDebounce?.cancel();
    controller.removeListener(_onTextChanged);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.all(widget.compact ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF171526),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C2941), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x067B4DFF),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xff6438FF),
                backgroundImage:
                    ProfileController.instance.avatarUrl?.isNotEmpty == true
                    ? NetworkImage(ProfileController.instance.avatarUrl!)
                    : null,
                child: ProfileController.instance.avatarUrl?.isNotEmpty == true
                    ? null
                    : const Icon(Icons.person, color: Colors.white),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: widget.compact ? 1 : 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: widget.placeholder,
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF14121E),

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
                    if (_searchingMentions)
                      const LinearProgressIndicator(
                        minHeight: 2,
                        color: Color(0xFF8B5CF6),
                      ),
                    if (_mentionSuggestions.isNotEmpty) _mentionMenu(),
                  ],
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
                  backgroundColor: const Color(0xFF7B4DFF),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: const Color(0x7F7B4DFF),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Publicar",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mentionMenu() => Container(
    margin: const EdgeInsets.only(top: 6),
    constraints: const BoxConstraints(maxHeight: 190),
    decoration: BoxDecoration(
      color: const Color(0xFF211E2E),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF4B3A73)),
    ),
    child: ListView.separated(
      shrinkWrap: true,
      itemCount: _mentionSuggestions.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFF39324F)),
      itemBuilder: (context, index) {
        final user = _mentionSuggestions[index];
        final name = user['username']?.toString() ?? 'Usuario';
        final avatar = user['avatar_url']?.toString() ?? '';
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFF6438FF),
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty
                ? Text(
                    name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          title: Text(
            '@$name',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          onTap: () => _insertMention(user),
        );
      },
    ),
  );
}
