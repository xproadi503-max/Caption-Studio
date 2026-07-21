import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

/// Extracts a compressed mono audio track from the source video so it
/// can be uploaded to the transcription API. Keeping this as a small
/// mp3 (instead of uploading the whole video) makes upload much faster
/// and is all the transcription API needs.
class AudioExtractor {
  /// Extracts audio from [videoPath] and writes an mp3 to a temp file.
  /// Returns the path to the extracted audio file.
  static Future<String> extractAudio(String videoPath) async {
    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/extracted_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';

    // Using executeWithArguments (array form) instead of a single command
    // string avoids any quote/tokenizing ambiguity around file paths.
    final arguments = <String>[
      '-i', videoPath,
      '-vn',
      '-ac', '1',
      '-ar', '16000',
      '-b:a', '64k',
      '-y',
      outputPath,
    ];

    final session = await FFmpegKit.executeWithArguments(arguments);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      throw Exception('Audio extraction failed:\n$logs');
    }
    return outputPath;
  }
}
