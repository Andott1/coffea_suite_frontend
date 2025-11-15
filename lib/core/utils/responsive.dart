import 'dart:math';
import 'package:flutter/material.dart';

/// =============================================================
/// Responsive Utility
/// -------------------------------------------------------------
///  - Uses Hanzhong T13 (1280x800) as baseline reference.
///  - Scales all UI and font sizes relative to screen diagonal.
///  - Ensures consistent readability across resolutions.
///  - Rounds font sizes to nearest 0.5px for pixel-perfect results.
/// =============================================================
class Responsive {
  final BuildContext context;
  late double screenWidth;
  late double screenHeight;
  late double scaleWidth;
  late double scaleHeight;
  late double scaleFactor;

  // Base diagonal reference: 1280x800
  static const double _baseWidth = 1280.0;
  static const double _baseHeight = 800.0;
  static final double _baseDiagonal =
      sqrt(_baseWidth * _baseWidth + _baseHeight * _baseHeight);

  Responsive(this.context) {
    final size = MediaQuery.of(context).size;
    screenWidth = size.width;
    screenHeight = size.height;

    scaleWidth = screenWidth / _baseWidth;
    scaleHeight = screenHeight / _baseHeight;

    // Compute diagonal-based scaling factor
    final diagonal = sqrt(screenWidth * screenWidth + screenHeight * screenHeight);
    scaleFactor = (diagonal / _baseDiagonal).clamp(0.9, 1.3);
  }

  // ────────────────────────────────────────────────
  // Layout helpers
  // ────────────────────────────────────────────────
  double wp(double percent) => screenWidth * (percent / 100);
  double hp(double percent) => screenHeight * (percent / 100);

  double scale(double value) => value * scaleWidth;

  // ────────────────────────────────────────────────
  // Font scaling (pixel-aligned, diagonal-based)
  // ────────────────────────────────────────────────
  double font(double size) {
    // Keep baseline for Hanzhong T13
    if (screenWidth.round() == _baseWidth.round() &&
        screenHeight.round() == _baseHeight.round()) {
      return size;
    }

    double scaled = size * scaleFactor;

    // Snap to nearest 0.5 px for crisp rendering
    double snapped = (scaled * 2).round() / 2;
    return snapped;
  }

  // ────────────────────────────────────────────────
  // Device classification
  // ────────────────────────────────────────────────
  bool get isTablet => MediaQuery.of(context).size.shortestSide >= 600;
  bool get isLargeScreen => screenWidth >= 1920;
}
