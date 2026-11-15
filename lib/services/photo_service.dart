import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Mengambil foto dari kamera/galeri dan menyimpannya di memori aplikasi.
class PhotoService {
  PhotoService._();
  static final PhotoService instance = PhotoService._();

  final ImagePicker _picker = ImagePicker();

  /// Mengembalikan path foto yang sudah disalin ke folder aplikasi, atau null bila batal.
  Future<String?> pick({bool camera = true, double maxSize = 1280, bool front = false}) async {
    if (camera) {
      // izin kamera wajib diminta dulu (aplikasi juga memakai kamera untuk scan tiket)
      final st = await Permission.camera.request();
      if (!st.isGranted) throw Exception('izin kamera ditolak');
    }
    final x = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: maxSize,
      maxHeight: maxSize,
      preferredCameraDevice: front ? CameraDevice.front : CameraDevice.rear,
      imageQuality: 80,
    );
    if (x == null) return null;
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/photos');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(x.path).copy(path);
    return path;
  }

  Future<void> delete(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }
}
