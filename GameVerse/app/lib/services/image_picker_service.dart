import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class ImagePickerService {
  static Future<Uint8List?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null) return null;

    return result.files.single.bytes;
  }
}
