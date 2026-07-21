import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:path_provider/path_provider.dart';

/// Burns a generated .ass subtitle file into a source video, producing
/// a final exported video with the animated captions baked in
/// (equivalent to Zeemo's "export" step).
class VideoExportService {
  /// [onProgress] receives 0.0-1.0 based on FFmpeg's reported time vs
  /// the video's total duration (durationMs).
  static Future<String> burnCaptions({
    required String videoPath,
    required String assFilePath,
    required int durationMs,
    void Function(double progress)? onProgress,
  }) async {
    final outputDir = await getApplicationDocumentsDirectory();
    final outputPath =
        '${outputDir.path}/caption_export_${DateTime.now().millisecondsSinceEpoch}.mp4';

    if (onProgress != null && durationMs > 0) {
      FFmpegKitConfig.enableStatisticsCallback((Statistics stats) {
        final timeMs = stats.getTime();
        if (timeMs > 0) {
          final progress = (timeMs / durationMs).clamp(0.0, 1.0);
          onProgress(progress);
        }
      });
    }

    // IMPORTANT: pass arguments as a list (executeWithArguments) rather
    // than a single command string. FFmpegKit's own string tokenizer can
    // mishandle nested quotes in filter args like ass='/path/to/file.ass'
    // on Android, which silently drops the subtitle filter (video exports
    // fine, but with no captions burned in, and no error surfaced).
    // Passing arguments directly as array elements avoids that entirely.
    final arguments = <String>[
      '-i', videoPath,
      '-vf', 'ass=$assFilePath',
      '-c:v', 'libx264',
      '-preset', 'fast',
      '-crf', '20',
      '-c:a', 'copy',
      '-y',
      outputPath,
    ];

    final session = await FFmpegKit.executeWithArguments(arguments);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      throw Exception('Caption burn-in failed:\n$logs');
    }

    final outFile = File(outputPath);
    if (!await outFile.exists()) {
      throw Exception('Export finished but output file was not found.');
    }
    return outputPath;
  }
}
