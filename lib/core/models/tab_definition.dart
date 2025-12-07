import 'package:flutter/material.dart';
import '../config/permissions_config.dart';

/// A shared configuration object for module tabs.
/// Used to map a Title -> Screen Widget -> Required Permission.
class TabDefinition {
  final String title;
  final Widget widget;
  final AppPermission? permission;

  const TabDefinition({
    required this.title,
    required this.widget,
    this.permission,
  });
}