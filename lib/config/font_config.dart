import 'package:flutter/material.dart';
import '../core/utils/responsive.dart';
import 'theme_config.dart';

class FontConfig {
  static TextStyle h1(BuildContext context) {
    final r = Responsive(context);
    return TextStyle(
      fontSize: r.font(26),
      fontWeight: FontWeight.bold,
      color: ThemeConfig.primaryGreen,
    );
  }

  static TextStyle h2(BuildContext context) {
    final r = Responsive(context);
    return TextStyle(
      fontSize: r.font(20),
      fontWeight: FontWeight.w600,
      color: ThemeConfig.primaryGreen,
    );
  }

  static TextStyle body(BuildContext context) {
    final r = Responsive(context);
    return TextStyle(
      fontSize: r.font(16),
      color: ThemeConfig.primaryGreen,
    );
  }

  static TextStyle caption(BuildContext context) {
    final r = Responsive(context);
    return TextStyle(
      fontSize: r.font(13),
      color: Colors.grey[700],
    );
  }

  static TextStyle button(BuildContext context) {
    final r = Responsive(context);
    return TextStyle(
      fontSize: r.font(18),
      fontWeight: FontWeight.w600,
      color: ThemeConfig.white,
    );
  }
}
