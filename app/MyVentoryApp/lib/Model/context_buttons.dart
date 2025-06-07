import 'package:flutter/material.dart';

class ContextButton extends StatelessWidget {
  final String concern;
  final Color c;
  final Function() action;

  const ContextButton(
      {super.key,
      required this.concern,
      required this.c,
      required this.action});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
        onPressed: action,
        style: ElevatedButton.styleFrom(
          fixedSize: Size(MediaQuery.of(context).size.width - 40, 25),
          backgroundColor: c,
          shadowColor: Colors.transparent,
        ),
        child: Text(
          concern,
          style: TextStyle(color: Colors.white, fontSize: 20),
        ));
  }
}

class GoBackButton extends StatelessWidget {
  final Widget pushedWidget;
  const GoBackButton({super.key, required this.pushedWidget});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: const EdgeInsets.all(4.0),
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () {
        Navigator.pop(context);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (BuildContext context) => pushedWidget),
        );
      },
    );
  }
}
