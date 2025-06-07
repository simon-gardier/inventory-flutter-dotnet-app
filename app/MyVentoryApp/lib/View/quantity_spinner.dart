import 'dart:async';
import 'package:flutter/material.dart';

class QuantitySpinner extends StatefulWidget {
  final TextEditingController controller;
  final double width;

  const QuantitySpinner({
    super.key,
    required this.controller,
    required this.width,
  });

  @override
  State<QuantitySpinner> createState() => QuantitySpinnerState();
}

class QuantitySpinnerState extends State<QuantitySpinner> {
  // Variables
  Timer? incrementTimer;
  Timer? decrementTimer;
  int currentSpeed = 300;
  final int minSpeed = 50;
  static const int maxQuantity = 999;

  @override
  void dispose() {
    incrementTimer?.cancel();
    decrementTimer?.cancel();
    super.dispose();
  }

  void startIncrementing() {
    incrementTimer?.cancel();

    incrementQuantity();

    currentSpeed = 300;
    incrementTimer =
        Timer.periodic(Duration(milliseconds: currentSpeed), (timer) {
      incrementQuantity();

      if (timer.tick % 3 == 0 && currentSpeed > minSpeed) {
        incrementTimer?.cancel();
        currentSpeed = (currentSpeed * 0.7).round();
        if (currentSpeed < minSpeed) currentSpeed = minSpeed;
        incrementTimer =
            Timer.periodic(Duration(milliseconds: currentSpeed), (timer) {
          incrementQuantity();
        });
      }
    });
  }

  void stopIncrementing() {
    incrementTimer?.cancel();
    incrementTimer = null;
  }

  void startDecrementing() {
    decrementTimer?.cancel();

    decrementQuantity();

    currentSpeed = 300;
    decrementTimer =
        Timer.periodic(Duration(milliseconds: currentSpeed), (timer) {
      decrementQuantity();

      if (timer.tick % 3 == 0 && currentSpeed > minSpeed) {
        decrementTimer?.cancel();
        currentSpeed = (currentSpeed * 0.7).round();
        if (currentSpeed < minSpeed) currentSpeed = minSpeed;
        decrementTimer =
            Timer.periodic(Duration(milliseconds: currentSpeed), (timer) {
          decrementQuantity();
        });
      }
    });
  }

  void stopDecrementing() {
    decrementTimer?.cancel();
    decrementTimer = null;
  }

  void incrementQuantity() {
    int? currentValue = int.tryParse(widget.controller.text);
    if (currentValue == null) {
      widget.controller.text = "0";
    } else if (currentValue < maxQuantity) {
      setState(() {
        widget.controller.text = (currentValue + 1).toString();
      });
    } else {
      stopIncrementing();
    }
  }

  void decrementQuantity() {
    int? currentValue = int.tryParse(widget.controller.text);
    if (currentValue == null) {
      widget.controller.text = "0";
    } else if (currentValue > 0) {
      setState(() {
        widget.controller.text = (currentValue - 1).toString();
      });
    } else {
      stopDecrementing();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color.fromARGB(255, 87, 143, 134),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTapDown: (_) => startDecrementing(),
            onTapUp: (_) => stopDecrementing(),
            onTapCancel: () => stopDecrementing(),
            child: Container(
              width: 30,
              height: 50,
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 131, 184, 175),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(0),
                  bottomLeft: Radius.circular(0),
                ),
              ),
              child: const Icon(Icons.remove, color: Colors.white),
            ),
          ),
          // Quantity field
          Expanded(
            child: TextField(
              controller: widget.controller..text = widget.controller.text.isEmpty ? "1" : widget.controller.text,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: "Quantity",
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
              int? newValue = int.tryParse(value);
              if (newValue == null || newValue < 1) {
                widget.controller.text = "1";
                widget.controller.selection = TextSelection.fromPosition(
                TextPosition(offset: widget.controller.text.length),
                );
              } else if (newValue > maxQuantity) {
                widget.controller.text = maxQuantity.toString();
                widget.controller.selection = TextSelection.fromPosition(
                TextPosition(offset: widget.controller.text.length),
                );
              }
              },
            ),
          ),
          // Increase button
          GestureDetector(
            onTapDown: (_) => startIncrementing(),
            onTapUp: (_) => stopIncrementing(),
            onTapCancel: () => stopIncrementing(),
            child: Container(
              width: 30,
              height: 50,
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 131, 184, 175),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(0),
                  bottomRight: Radius.circular(0),
                ),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
