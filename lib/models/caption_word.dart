/// A single transcribed word with its start/end time (in milliseconds)
/// relative to the start of the video. This word-level granularity is
/// what enables karaoke-style / word-highlight animations like Zeemo,
/// CapCut, and similar caption tools use.
class CaptionWord {
  final String text;
  final int startMs;
  final int endMs;
  final double confidence;
  final int? speaker; // speaker index if diarization is enabled

  CaptionWord({
    required this.text,
    required this.startMs,
    required this.endMs,
    this.confidence = 1.0,
    this.speaker,
  });

  factory CaptionWord.fromAssemblyAiJson(Map<String, dynamic> json) {
    return CaptionWord(
      text: json['text'] as String,
      startMs: json['start'] as int,
      endMs: json['end'] as int,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      speaker: json['speaker'] != null
          ? int.tryParse(json['speaker'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'start': startMs,
        'end': endMs,
        'confidence': confidence,
        'speaker': speaker,
      };
}

/// A group of words shown together as one caption "card" on screen
/// (e.g. 3-6 words at a time), which is how short-form video captions
/// are typically chunked rather than showing a whole sentence at once.
class CaptionLine {
  final List<CaptionWord> words;

  CaptionLine(this.words);

  int get startMs => words.first.startMs;
  int get endMs => words.last.endMs;
  String get fullText => words.map((w) => w.text).join(' ');

  /// Returns a new [CaptionLine] with the same overall start/end time but
  /// with [newText]'s words evenly spaced across that duration. Used when
  /// the user manually edits a caption line's text — we don't have real
  /// per-word timing for the corrected text, so an even split is the
  /// simplest reasonable approximation.
  CaptionLine withTextOverride(String newText) {
    final newWords = newText.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (newWords.isEmpty) return this;
    final totalMs = endMs - startMs;
    final perWordMs = (totalMs / newWords.length).round().clamp(1, totalMs);
    final rebuilt = <CaptionWord>[];
    for (int i = 0; i < newWords.length; i++) {
      final wordStart = startMs + (i * perWordMs);
      final wordEnd = (i == newWords.length - 1) ? endMs : wordStart + perWordMs;
      rebuilt.add(CaptionWord(text: newWords[i], startMs: wordStart, endMs: wordEnd));
    }
    return CaptionLine(rebuilt);
  }

  /// Groups a flat list of words into caption lines, breaking on
  /// [maxWordsPerLine] words or [maxGapMs] of silence between words.
  static List<CaptionLine> groupWords(
    List<CaptionWord> words, {
    int maxWordsPerLine = 5,
    int maxGapMs = 700,
    int maxCharsPerLine = 28,
  }) {
    final lines = <CaptionLine>[];
    var current = <CaptionWord>[];
    int currentChars = 0;

    for (final word in words) {
      final wouldBreakOnGap = current.isNotEmpty &&
          (word.startMs - current.last.endMs) > maxGapMs;
      final wouldBreakOnCount = current.length >= maxWordsPerLine;
      final wouldBreakOnChars =
          (currentChars + word.text.length + 1) > maxCharsPerLine;

      if (current.isNotEmpty &&
          (wouldBreakOnGap || wouldBreakOnCount || wouldBreakOnChars)) {
        lines.add(CaptionLine(List.of(current)));
        current = [];
        currentChars = 0;
      }
      current.add(word);
      currentChars += word.text.length + 1;
    }
    if (current.isNotEmpty) {
      lines.add(CaptionLine(List.of(current)));
    }
    return lines;
  }

  /// Applies a lineIndex -> replacement text map to a list of caption
  /// lines, returning a new list with edited lines' words re-timed evenly
  /// across their original duration. Lines without an override are
  /// returned unchanged.
  static List<CaptionLine> applyTextOverrides(
    List<CaptionLine> lines,
    Map<int, String> textOverrides,
  ) {
    return List.generate(lines.length, (i) {
      final override = textOverrides[i];
      if (override == null || override.trim().isEmpty) return lines[i];
      return lines[i].withTextOverride(override);
    });
  }
}
