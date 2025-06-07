import 'package:flutter/material.dart';

class ShortcutItem extends PopupMenuEntry<int> {
  final int value;
  final IconData icon;
  final String text;

  const ShortcutItem({
    super.key,
    required this.value,
    required this.icon,
    required this.text,
  });

  @override
  double get height => kMinInteractiveDimension;

  @override
  bool represents(int? value) => value == this.value;

  @override
  State<ShortcutItem> createState() => ShortcutItemState();
}

  class ShortcutItemState extends State<ShortcutItem> {
  @override
  Widget build(BuildContext context) {
    return PopupMenuItem<int>(
      value: widget.value,
      child: Row(
        children: [
          Icon(widget.icon),
          const SizedBox(width: 8),
          Text(widget.text),
        ],
      ),
    );
  }
}