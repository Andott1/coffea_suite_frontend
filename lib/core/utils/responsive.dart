import 'package:flutter/material.dart';

class Responsive {
  final BuildContext context;
  late double screenWidth;
  late double screenHeight;
  late double scaleWidth;
  late double scaleHeight;
  late double textScale;

  Responsive(this.context) {
    final size = MediaQuery.of(context).size;
    screenWidth = size.width;
    screenHeight = size.height;

    // Base reference: 1280x800 tablet
    scaleWidth = screenWidth / 1280;
    scaleHeight = screenHeight / 800;
    textScale = _determineTextScale();
  }

  // ────────────────────────────────────────────────
  // ✅ Dynamic text scaling per device type
  // ────────────────────────────────────────────────
  double _determineTextScale() {
    final shortestSide = MediaQuery.of(context).size.shortestSide;

    if (shortestSide < 600) {
      // Phones — slightly reduce font scaling
      return ((scaleWidth + scaleHeight) / 2) * 0.9;
    } else if (shortestSide < 900) {
      // Small tablets (7–9 inch)
      return ((scaleWidth + scaleHeight) / 2) * 1.0;
    } else {
      // Large tablets / desktops — keep base or slightly upscale
      return ((scaleWidth + scaleHeight) / 2) * 1.1;
    }
  }

  // ────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────
  double wp(double percent) => screenWidth * (percent / 100);
  double hp(double percent) => screenHeight * (percent / 100);

  double scale(double value) => value * scaleWidth;

  // ✅ Pixel-aligned font sizes
  double font(double size) {
    final scaled = size * textScale;
    final snapped = (scaled * MediaQuery.of(context).devicePixelRatio).round() /
        MediaQuery.of(context).devicePixelRatio;
    return snapped; // Snap to physical device pixels
  }

  bool get isTablet {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return shortestSide >= 600;
  }
}
