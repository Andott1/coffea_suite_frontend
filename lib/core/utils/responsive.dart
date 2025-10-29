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

    // Base reference for Hanzhong T13 tablet (1280x800)
    scaleWidth = screenWidth / 1280;
    scaleHeight = screenHeight / 800;
    textScale = (scaleWidth + scaleHeight) / 2;
  }

  double wp(double percent) => screenWidth * (percent / 100);
  double hp(double percent) => screenHeight * (percent / 100);

  double scale(double value) => value * scaleWidth;
  double font(double size) => size * textScale;
}