import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Model/text_boxes.dart';

class VisibilityButton extends StatefulWidget {
  final VoidCallback toggleObscure;
  final GlobalKey<TextBoxState> textBoxKey;

  const VisibilityButton(
      {super.key, required this.toggleObscure, required this.textBoxKey});

  @override
  State<VisibilityButton> createState() => VisibilityButtonState();
}

class VisibilityButtonState extends State<VisibilityButton> {
  @override
  Widget build(BuildContext context) {
    bool isObscured = !(widget.textBoxKey.currentState?.isObscureText ?? true);

    return IconButton(
      icon: Icon(
        isObscured ? Icons.visibility : Icons.visibility_off,
      ),
      onPressed: () {
        setState(() {
          widget.toggleObscure();
        });
      },
    );
  }
}
