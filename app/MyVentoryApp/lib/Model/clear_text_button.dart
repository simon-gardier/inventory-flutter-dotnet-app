import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Model/text_boxes.dart';

class ClearTextButton extends StatefulWidget {
  final GlobalKey<TextBoxState> textBoxKey;
  final TextEditingController boxC;

  const ClearTextButton(
      {super.key, required this.textBoxKey, required this.boxC});

  @override
  State<ClearTextButton> createState() => ClearTextButtonState();
}

class ClearTextButtonState extends State<ClearTextButton> {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.cancel_outlined,
        color: Colors.black,
      ),
      onPressed: () {
        setState(() {
          widget.textBoxKey.currentState?.widget.boxC.clear();
        });
      },
    );
  }
}
