import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';

/// Fondo reutilizable del feed cargado desde Supabase Storage.
///
/// El bucket debe ser público porque se obtiene una URL pública del archivo.
class FeedBackground extends StatelessWidget {
  const FeedBackground({
    super.key,
    this.bucketId = 'app-assets',
    this.objectPath = 'feed/default-background.png',
  });

  final String bucketId;
  final String objectPath;

  String? _publicUrl() {
    final bucket = bucketId.trim();
    final path = objectPath.trim();

    if (bucket.isEmpty || path.isEmpty) return null;

    try {
      return Supabase.instance.client.storage.from(bucket).getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _publicUrl();

    if (imageUrl == null) {
      return const SizedBox.expand(
        child: ColoredBox(color: AppColors.background),
      );
    }

    return IgnorePointer(
      child: SizedBox.expand(
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress != null) {
              return const ColoredBox(color: Color(0xFF101014));
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                child,
                const ColoredBox(
                  color: Color.fromRGBO(0, 0, 0, 0.45),
                ),
              ],
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              const ColoredBox(color: AppColors.background),
        ),
      ),
    );
  }
}
