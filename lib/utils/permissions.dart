import 'package:permission_handler/permission_handler.dart';

/// Requests the storage/photos permissions needed to pick a video and
/// later save the exported video to the gallery.
class AppPermissions {
  static Future<bool> requestMediaPermissions() async {
    final statuses = await [
      Permission.photos,
      Permission.videos,
      Permission.storage,
    ].request();

    return statuses.values.any((s) => s.isGranted);
  }
}
