import 'video_metadata_helper_stub.dart'
    if (dart.library.html) 'video_metadata_helper_web.dart';

class VideoMetadataHelper {
  static Future<Map<String, dynamic>> extractMetadata(dynamic bytes, String fileName) {
    return extractVideoMetadataImpl(bytes, fileName);
  }
}
