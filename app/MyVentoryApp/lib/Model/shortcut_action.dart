import 'package:flutter/material.dart';

class ShortcutAction {
  final int value;
  final IconData icon;
  final String text;
  final VoidCallback action;

  ShortcutAction({
    required this.value,
    required this.icon,
    required this.text,
    required this.action,
  });
}