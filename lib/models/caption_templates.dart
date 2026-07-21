import 'package:flutter/material.dart';
import 'caption_style.dart';

/// A curated set of caption templates covering the most common
/// short-form-video caption styles (word-highlight/karaoke, pop,
/// bounce, typewriter, etc). Good enough variety to feel like a
/// real template library without maintaining hundreds of near-duplicates.
class CaptionTemplates {
  static const List<CaptionTemplate> all = [
    CaptionTemplate(
      id: 'classic_highlight',
      name: 'Classic Highlight',
      animation: CaptionAnimation.wordHighlight,
      textColor: Colors.white,
      highlightColor: Colors.yellowAccent,
      strokeColor: Colors.black,
    ),
    CaptionTemplate(
      id: 'bold_pop',
      name: 'Bold Pop',
      animation: CaptionAnimation.popIn,
      textColor: Colors.white,
      highlightColor: Colors.orangeAccent,
      fontWeight: FontWeight.w900,
      fontSize: 1.15,
    ),
    CaptionTemplate(
      id: 'neon_bounce',
      name: 'Neon Bounce',
      animation: CaptionAnimation.bounce,
      textColor: Colors.white,
      highlightColor: Color(0xFF39FF14),
      strokeColor: Colors.black,
    ),
    CaptionTemplate(
      id: 'typewriter_clean',
      name: 'Typewriter',
      animation: CaptionAnimation.typewriter,
      textColor: Colors.white,
      highlightColor: Colors.white,
      backgroundColor: Color(0xCC000000),
      fontWeight: FontWeight.w600,
    ),
    CaptionTemplate(
      id: 'hormozi_style',
      name: 'Creator Bold',
      animation: CaptionAnimation.wordHighlight,
      textColor: Colors.white,
      highlightColor: Color(0xFF00E676),
      strokeColor: Colors.black,
      strokeWidth: 3.0,
      fontWeight: FontWeight.w900,
      fontSize: 1.25,
    ),
    CaptionTemplate(
      id: 'pastel_box',
      name: 'Pastel Box',
      animation: CaptionAnimation.fadeWord,
      textColor: Color(0xFF2D2D2D),
      highlightColor: Color(0xFFFF6F91),
      backgroundColor: Color(0xFFFFF3E0),
      strokeWidth: 0,
    ),
    CaptionTemplate(
      id: 'slide_minimal',
      name: 'Slide Minimal',
      animation: CaptionAnimation.slideUp,
      textColor: Colors.white,
      highlightColor: Colors.white,
      backgroundColor: Color(0x99000000),
      fontWeight: FontWeight.w500,
    ),
    CaptionTemplate(
      id: 'karaoke_pink',
      name: 'Karaoke Pink',
      animation: CaptionAnimation.wordHighlight,
      textColor: Colors.white70,
      highlightColor: Color(0xFFFF3B7F),
      strokeColor: Colors.black,
    ),
    CaptionTemplate(
      id: 'blue_pop',
      name: 'Electric Pop',
      animation: CaptionAnimation.popIn,
      textColor: Colors.white,
      highlightColor: Color(0xFF00B4FF),
      strokeColor: Colors.black,
      fontSize: 1.1,
    ),
    CaptionTemplate(
      id: 'top_bar_static',
      name: 'Top Static',
      animation: CaptionAnimation.none,
      textColor: Colors.white,
      highlightColor: Colors.white,
      backgroundColor: Color(0xB3000000),
      position: Alignment.topCenter,
    ),
    CaptionTemplate(
      id: 'gold_bounce',
      name: 'Gold Bounce',
      animation: CaptionAnimation.bounce,
      textColor: Colors.white,
      highlightColor: Color(0xFFFFD700),
      strokeColor: Colors.black,
      fontWeight: FontWeight.w900,
    ),
    CaptionTemplate(
      id: 'subtle_fade',
      name: 'Subtle Fade',
      animation: CaptionAnimation.fadeWord,
      textColor: Colors.white,
      highlightColor: Colors.white,
      strokeColor: Colors.black45,
      fontWeight: FontWeight.w400,
      fontSize: 0.9,
    ),
  ];

  static CaptionTemplate byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => all.first);
}
