import 'package:flutter/material.dart';
import '../models/caption_word.dart';
import '../models/caption_style.dart';

/// Builds an .ass (Advanced SubStation Alpha) subtitle file from a list
/// of timestamped words plus a chosen [CaptionTemplate]. FFmpeg can burn
/// .ass subtitles directly into a video with full styling/animation
/// support, which is how the final "export" step gets Zeemo-style
/// animated captions baked into the output video.
///
/// Strategy: rather than relying on native ASS \k karaoke timing (which
/// has quirky player-dependent behaviour), we generate one Dialogue
/// event per word "step" within each caption line. Each step shows the
/// full line text with override tags applied only to the currently
/// active word. This gives precise, predictable control over every
/// animation style (highlight, pop, bounce, typewriter reveal, fade)
/// using the same core loop.
class AssGenerator {
  static String generate({
    required List<CaptionWord> words,
    required CaptionTemplate template,
    int maxWordsPerLine = 5,
    int videoWidth = 1080,
    int videoHeight = 1920,
    Map<int, Offset>? positionOverrides,
    Map<int, String>? textOverrides,
  }) {
    var lines = CaptionLine.groupWords(words, maxWordsPerLine: maxWordsPerLine);
    if (textOverrides != null && textOverrides.isNotEmpty) {
      lines = CaptionLine.applyTextOverrides(lines, textOverrides);
    }
    final buffer = StringBuffer();

    buffer.writeln(_header(videoWidth, videoHeight));
    buffer.writeln(_stylesSection(template, videoWidth));
    buffer.writeln('[Events]');
    buffer.writeln(
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');

    for (int i = 0; i < lines.length; i++) {
      buffer.write(_eventsForLine(
        lines[i],
        template,
        positionOverride: positionOverrides?[i],
        videoWidth: videoWidth,
        videoHeight: videoHeight,
      ));
    }

    return buffer.toString();
  }

  static String _header(int w, int h) => '''
[Script Info]
Title: Auto-generated captions
ScriptType: v4.00+
PlayResX: $w
PlayResY: $h
WrapStyle: 0
ScaledBorderAndShadow: yes
''';

  static String _stylesSection(CaptionTemplate t, int videoWidth) {
    final fontSize = (videoWidth * 0.065 * t.fontSize).round();
    final primary = _colorToAss(t.textColor);
    final highlight = _colorToAss(t.highlightColor);
    final outline = _colorToAss(t.strokeColor);
    final back = t.backgroundColor != null
        ? _colorToAss(t.backgroundColor!)
        : '&H00000000&';
    final bold = t.fontWeight.index >= FontWeight.w700.index ? -1 : 0;
    final alignment = _assAlignment(t.position);
    final marginV = (videoHeightMargin(t.position) * videoWidth ~/ 1080);

    return '''
[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Base,${t.fontFamily},$fontSize,$primary,$highlight,$outline,$back,$bold,0,0,0,100,100,0,0,${t.backgroundColor != null ? 3 : 1},${t.strokeWidth},0,$alignment,60,60,$marginV,1
''';
  }

  static int videoHeightMargin(Alignment position) {
    if (position == Alignment.topCenter) return 80;
    if (position == Alignment.center) return 0;
    return 160; // bottomCenter default
  }

  static int _assAlignment(Alignment position) {
    // ASS numpad alignment: 2 = bottom-center, 8 = top-center, 5 = middle-center
    if (position == Alignment.topCenter) return 8;
    if (position == Alignment.center) return 5;
    return 2;
  }

  /// Converts a Flutter [Color] to ASS's &HAABBGGRR& hex format.
  static String _colorToAss(Color c) {
    String hex(int v) => v.toRadixString(16).padLeft(2, '0');
    final a = hex(255 - c.alpha); // ASS alpha is inverted (00=opaque)
    final b = hex(c.blue);
    final g = hex(c.green);
    final r = hex(c.red);
    return '&H$a$b$g$r&'.toUpperCase().replaceFirst('&H', '&H');
  }

  static String _timestamp(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final cs = (d.inMilliseconds % 1000) ~/ 10;
    return '${h.toString().padLeft(1, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
  }

  /// Escapes ASS special characters in plain word text.
  static String _escape(String text) => text.replaceAll('{', '(').replaceAll('}', ')');

  static String _eventsForLine(
    CaptionLine line,
    CaptionTemplate t, {
    Offset? positionOverride,
    int videoWidth = 1080,
    int videoHeight = 1920,
  }) {
    final buffer = StringBuffer();
    final words = line.words;
    final posTag = positionOverride != null
        ? '{\\an5\\pos(${(positionOverride.dx * videoWidth).round()},${(positionOverride.dy * videoHeight).round()})}'
        : '';

    for (int i = 0; i < words.length; i++) {
      final active = words[i];
      final start = active.startMs;
      // Each word stays "active" until the next word starts, or line end.
      final end = (i < words.length - 1) ? words[i + 1].startMs : line.endMs + 200;

      final text = posTag + _buildLineText(words, i, t);
      buffer.writeln(
          'Dialogue: 0,${_timestamp(start)},${_timestamp(end)},Base,,0,0,0,,$text');
    }
    return buffer.toString();
  }

  /// Builds the override-tagged line text for the step where word index
  /// [activeIndex] is currently active, applying the template's
  /// animation effect only to that word.
  static String _buildLineText(
      List<CaptionWord> words, int activeIndex, CaptionTemplate t) {
    final parts = <String>[];
    for (int i = 0; i < words.length; i++) {
      final w = _escape(words[i].text);
      if (i != activeIndex) {
        // Non-active words: for fadeWord/typewriter, only show words up to
        // (and including) the active one; otherwise show plain text.
        if ((t.animation == CaptionAnimation.typewriter ||
                t.animation == CaptionAnimation.fadeWord) &&
            i > activeIndex) {
          continue; // not revealed yet
        }
        parts.add(w);
      } else {
        parts.add(_activeWordTag(w, t));
      }
    }
    return parts.join(r'\N'.replaceAll(r'\N', ' '));
  }

  static String _activeWordTag(String word, CaptionTemplate t) {
    final highlight = _colorToAss(t.highlightColor);
    switch (t.animation) {
      case CaptionAnimation.wordHighlight:
        return '{\\c$highlight}$word{\\r}';
      case CaptionAnimation.popIn:
        return '{\\t(0,120,\\fscx125\\fscy125)\\t(120,240,\\fscx100\\fscy100)\\c$highlight}$word{\\r}';
      case CaptionAnimation.bounce:
        return '{\\t(0,90,\\frz-4\\fscy112)\\t(90,220,\\frz0\\fscy100)\\c$highlight}$word{\\r}';
      case CaptionAnimation.typewriter:
        return '{\\c$highlight}$word{\\r}';
      case CaptionAnimation.slideUp:
        return word;
      case CaptionAnimation.fadeWord:
        return '{\\fad(180,0)\\c$highlight}$word{\\r}';
      case CaptionAnimation.none:
        return word;
    }
  }
}
