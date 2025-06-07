import 'package:flutter/material.dart';

class SegmentOption {
  final String label;
  final IconData icon;

  SegmentOption({required this.label, required this.icon});
}

class SingleChoiceSegmentedButton extends StatefulWidget {
  final List<SegmentOption> options;
  final VoidCallback onSegmentButtonChange;

  const SingleChoiceSegmentedButton({
    super.key,
    required this.options,
    required this.onSegmentButtonChange,
  });

  @override
  State<SingleChoiceSegmentedButton> createState() =>
      SingleChoiceSegmentedButtonState();
}

class SingleChoiceSegmentedButtonState
    extends State<SingleChoiceSegmentedButton> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width - 20,
      child: SegmentedButton<int>(
        segments: List.generate(widget.options.length, (index) {
          return ButtonSegment<int>(
            value: index,
            label: Text(widget.options[index].label),
            icon: Icon(widget.options[index].icon),
          );
        }),
        selected: {selectedIndex},
        onSelectionChanged: (Set<int> newSelection) {
          setState(() {
            selectedIndex = newSelection.first;
          });
          widget.onSegmentButtonChange();
        },
      ),
    );
  }
}
