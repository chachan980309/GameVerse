class GameSearchResult {
  final int id;
  final String name;
  final String? coverUrl;
  final List<String> platforms;
  
  final String posterImage;
  final String heroImage;
  final String backgroundImage;
  final List<String> screenshots;

  const GameSearchResult({
    required this.id,
    required this.name,
    this.coverUrl,
    required this.platforms,
    required this.posterImage,
    required this.heroImage,
    required this.backgroundImage,
    required this.screenshots,
  });

  String get suggestedPlatform => platforms.isNotEmpty ? platforms.first : '';

  static Map<String, dynamic> resolveGameImages({
    String? coverUrl,
    List<dynamic> artworks = const [],
    List<dynamic> screenshots = const [],
  }) {
    // Normalizar una URL de IGDB a un formato seguro y de alta definición (t_1080p)
    String normalizeUrl(String? url, {String size = 't_1080p'}) {
      if (url == null || url.isEmpty) return '';
      var clean = url;
      if (clean.startsWith('//')) {
        clean = 'https:$clean';
      }
      return clean
          .replaceAll('/t_thumb/', '/$size/')
          .replaceAll('/t_cover_small/', '/$size/')
          .replaceAll('/t_cover_big/', '/$size/')
          .replaceAll('/t_logo_med/', '/$size/')
          .replaceAll('/t_screenshot_med/', '/$size/')
          .replaceAll('/t_screenshot_big/', '/$size/')
          .replaceAll('/t_screenshot_huge/', '/$size/')
          .replaceAll('/t_artwork_large/', '/$size/');
    }

    // 1. posterImage: cover original de IGDB en alta resolución
    final posterImage = normalizeUrl(coverUrl, size: 't_cover_big');

    // Mapear y normalizar screenshots y artworks
    final normalizedArtworks = artworks.map((art) {
      final artMap = art as Map<String, dynamic>? ?? {};
      return {
        'url': normalizeUrl(artMap['url']?.toString(), size: 't_1080p'),
        'width': int.tryParse(artMap['width']?.toString() ?? '0') ?? 0,
        'height': int.tryParse(artMap['height']?.toString() ?? '0') ?? 0,
      };
    }).toList();

    final normalizedScreenshots = screenshots.map((sc) {
      final scMap = sc as Map<String, dynamic>? ?? {};
      return {
        'url': normalizeUrl(scMap['url']?.toString(), size: 't_1080p'),
        'width': int.tryParse(scMap['width']?.toString() ?? '0') ?? 0,
        'height': int.tryParse(scMap['height']?.toString() ?? '0') ?? 0,
      };
    }).toList();

    // Extraer lista de URLs puras de screenshots para exportar
    final screenshotsUrls = normalizedScreenshots.map((sc) => sc['url'] as String).where((url) => url.isNotEmpty).toList();

    // 2. heroImage: horizontal panorámica
    // Prioridad: 
    // 1. Primer artwork horizontal (width > height)
    // 2. Segundo artwork horizontal
    // 3. Primer screenshot horizontal
    // 4. Otro screenshot horizontal
    // 5. backgroundImage (que se resuelve abajo)
    // 6. posterImage como último recurso
    String? heroImage;
    for (final art in normalizedArtworks) {
      final w = art['width'] as int? ?? 0;
      final h = art['height'] as int? ?? 0;
      if (w > h && art['url'].toString().isNotEmpty) {
        heroImage = art['url'].toString();
        break;
      }
    }
    
    if (heroImage == null) {
      for (final sc in normalizedScreenshots) {
        final w = sc['width'] as int? ?? 0;
        final h = sc['height'] as int? ?? 0;
        if (w > h && sc['url'].toString().isNotEmpty) {
          heroImage = sc['url'].toString();
          break;
        }
      }
    }

    // 3. backgroundImage: cinematográfica de alta resolución
    // Prioridad:
    // 1. Artwork de mayor calidad o resolución (el primero)
    // 2. Segundo artwork
    // 3. Screenshot panorámico de alta resolución (el primero)
    // 4. heroImage
    // 5. posterImage
    String? backgroundImage;
    if (normalizedArtworks.isNotEmpty) {
      backgroundImage = normalizedArtworks.first['url'].toString();
    } else if (normalizedScreenshots.isNotEmpty) {
      backgroundImage = normalizedScreenshots.first['url'].toString();
    }

    // Unificar referencias cruzadas y fallbacks
    backgroundImage ??= heroImage ?? posterImage;
    heroImage ??= backgroundImage; // Si no hay heroImage, usar backgroundImage (que a su vez usará posterImage si hace falta)

    // Fallbacks elegantes de GameVerse si todo está vacío
    const defaultPlaceholder = 'https://kspeynuvzzglafckkiza.supabase.co/storage/v1/object/public/tournaments/default_game_placeholder.jpg';
    
    return {
      'posterImage': posterImage.isNotEmpty ? posterImage : defaultPlaceholder,
      'heroImage': heroImage.isNotEmpty ? heroImage : defaultPlaceholder,
      'backgroundImage': backgroundImage.isNotEmpty ? backgroundImage : defaultPlaceholder,
      'screenshots': screenshotsUrls,
    };
  }

  factory GameSearchResult.fromMap(Map<String, dynamic> map) {
    final resolved = resolveGameImages(
      coverUrl: map['cover_url']?.toString(),
      artworks: map['artworks'] as List<dynamic>? ?? const [],
      screenshots: map['screenshots'] as List<dynamic>? ?? const [],
    );

    final name = map['name']?.toString() ?? '';
    print("[LOG-IGDB-DIAGNOSTIC] === JUEGO RECIBIDO DESDE IGDB ===");
    print("  - Nombre del juego: $name");
    print("  - Cover recibido: ${map['cover_url']}");
    print("  - Artworks: ${map['artworks']}");
    print("  - Screenshots: ${map['screenshots']}");
    print("  - heroImage elegida: ${resolved['heroImage']}");
    print("  - backgroundImage elegida: ${resolved['backgroundImage']}");
    print("=======================================================");

    return GameSearchResult(
      id: int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      name: name,
      coverUrl: map['cover_url']?.toString(),
      platforms: (map['platforms'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(),
      posterImage: resolved['posterImage'] as String,
      heroImage: resolved['heroImage'] as String,
      backgroundImage: resolved['backgroundImage'] as String,
      screenshots: List<String>.from(resolved['screenshots'] as List<dynamic>? ?? const []),
    );
  }
}
