import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/caption_word.dart';

/// Handles talking to the AssemblyAI API to turn an audio file into
/// word-level timestamped text. AssemblyAI was chosen because it has
/// a straightforward REST API, a usable free tier, and returns
/// word-level timing + speaker labels out of the box (no extra work
/// needed to get karaoke-style timing like WhisperX would require).
///
/// Docs: https://www.assemblyai.com/docs
class TranscriptionService {
  static const _baseUrl = 'https://api.assemblyai.com/v2';
  final String apiKey;

  TranscriptionService(this.apiKey);

  Map<String, String> get _headers => {
        'authorization': apiKey,
        'content-type': 'application/json',
      };

  /// Step 1: upload local audio file bytes, get back a hosted URL
  /// that AssemblyAI can transcribe.
  Future<String> uploadAudio(File audioFile) async {
    final bytes = await audioFile.readAsBytes();
    final response = await http.post(
      Uri.parse('$_baseUrl/upload'),
      headers: {'authorization': apiKey},
      body: bytes,
    );
    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.statusCode} ${response.body}');
    }
    final data = jsonDecode(response.body);
    return data['upload_url'] as String;
  }

  /// Step 2: request transcription for the uploaded audio URL.
  /// Returns the transcript id used for polling.
  Future<String> requestTranscript(
    String audioUrl, {
    bool speakerLabels = true,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/transcript'),
      headers: _headers,
      body: jsonEncode({
        'audio_url': audioUrl,
        'speaker_labels': speakerLabels,
        'punctuate': true,
        'format_text': true,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
          'Transcript request failed: ${response.statusCode} ${response.body}');
    }
    final data = jsonDecode(response.body);
    return data['id'] as String;
  }

  /// Step 3: poll until the transcript is ready (or errors out).
  /// Calls [onStatus] with each raw status string so the UI can show
  /// progress like "queued" -> "processing" -> "completed".
  Future<List<CaptionWord>> pollUntilComplete(
    String transcriptId, {
    void Function(String status)? onStatus,
    Duration pollInterval = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final response = await http.get(
        Uri.parse('$_baseUrl/transcript/$transcriptId'),
        headers: _headers,
      );
      if (response.statusCode != 200) {
        throw Exception(
            'Polling failed: ${response.statusCode} ${response.body}');
      }
      final data = jsonDecode(response.body);
      final status = data['status'] as String;
      onStatus?.call(status);

      if (status == 'completed') {
        final words = (data['words'] as List<dynamic>? ?? [])
            .map((w) => CaptionWord.fromAssemblyAiJson(w as Map<String, dynamic>))
            .toList();
        return words;
      } else if (status == 'error') {
        throw Exception('Transcription error: ${data['error']}');
      }
      await Future.delayed(pollInterval);
    }
    throw Exception('Transcription timed out');
  }

  /// Convenience method that runs the full upload -> transcribe -> poll
  /// pipeline in one call.
  Future<List<CaptionWord>> transcribeAudioFile(
    File audioFile, {
    void Function(String status)? onStatus,
  }) async {
    onStatus?.call('uploading');
    final url = await uploadAudio(audioFile);
    onStatus?.call('queued');
    final id = await requestTranscript(url);
    return pollUntilComplete(id, onStatus: onStatus);
  }
}
