import 'package:flutter/material.dart';

/// The animation behaviour applied to each caption line/word.
enum CaptionAnimation {
  none, // static, just appears
  wordHighlight, // active word changes color (karaoke)
  popIn, // each word pops/scales in
  bounce, // active word bounces up slightly
  typewriter, // characters reveal left to right
  slideUp, // line slides up from below
  fadeWord, // words fade in one by one, all stay visible
}

/// A caption template: visual style + animation behaviour.
/// This is the Flutter-side definition used for the live preview overlay.
/// It also maps to an ASS (Advanced SubStation) subtitle style used when
/// burning captions into the final exported video via FFmpeg.
class CaptionTemplate {
  final String id;
  final String name;
  final CaptionAnimation animation;
  final Color textColor;
  final Color highlightColor; // color of the "active" word, if applicable
  final Color? backgroundColor; // pill/box background, null = none
  final Color strokeColor;
  final double strokeWidth;
  final String fontFamily;
  final FontWeight fontWeight;
  final double fontSize; // relative size, 1.0 = default
  final Alignment position;

  const CaptionTemplate({
    required this.id,
    required this.name,
    required this.animation,
    required this.textColor,
    required this.highlightColor,
    this.backgroundColor,
    this.strokeColor = Colors.black,
    this.strokeWidth = 2.0,
    this.fontFamily = 'Roboto',
    this.fontWeight = FontWeight.w800,
    this.fontSize = 1.0,
    this.position = Alignment.bottomCenter,
  });
}
