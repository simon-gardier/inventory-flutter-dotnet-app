import 'package:flutter/material.dart';

class MultipleChoiceButton extends StatefulWidget {
  final String backText;
  final double boxWidth;
  final double boxHeight;
  final int identifier;
  final void Function(String, int) returnType;
  final List<String>? fields;
  final String? prefillType;
  final ValueNotifier<String>? typeNotifier;

  const MultipleChoiceButton({
    super.key,
    required this.backText,
    required this.boxWidth,
    double? boxHeight,
    required this.returnType,
    required this.identifier,
    this.fields,
    this.prefillType,
    this.typeNotifier,
  }) : boxHeight = boxHeight ?? 0;

  @override
  State<MultipleChoiceButton> createState() => MultipleChoiceButtonState();
}

class MultipleChoiceButtonState extends State<MultipleChoiceButton> {
  String? selectedType;
  final List<String> types = [
    "Category",
    "Date",
    "Text",
    "Number",
    "Currency",
    "Link"
  ];

  @override
  void initState() {
    super.initState();
    // Chooses between provided fields or built-in types
    final List<String> optionsList = widget.fields ?? types;

    if (widget.prefillType != null && widget.prefillType!.isNotEmpty) {
      if (optionsList.contains(widget.prefillType)) {
        selectedType = widget.prefillType;
      } else {
        selectedType = optionsList.isNotEmpty ? optionsList[0] : null;
      }
    } else {
      selectedType = optionsList.isNotEmpty ? optionsList[0] : null;
    }

    // Notifies parent of initial selection
    if (selectedType != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.returnType(selectedType!, widget.identifier);
      });
    }
  }

  @override
  void didUpdateWidget(MultipleChoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.fields != widget.fields ||
        oldWidget.prefillType != widget.prefillType) {
      final List<String> optionsList = widget.fields ?? types;

      if (selectedType == null || !optionsList.contains(selectedType)) {
        if (widget.prefillType != null &&
            optionsList.contains(widget.prefillType)) {
          setState(() {
            selectedType = widget.prefillType;
          });
        } else if (optionsList.isNotEmpty) {
          setState(() {
            selectedType = optionsList[0];
          });
        } else {
          setState(() {
            selectedType = null;
          });
        }

        // Notifies parent of updated selection
        if (selectedType != null) {
          widget.returnType(selectedType!, widget.identifier);
        }
      }
    }
  }

  void updateSelectedType(String selectionType) {
    setState(() {
      selectedType = selectionType;
    });
    if (widget.typeNotifier != null) {
      widget.typeNotifier!.value = selectionType;
    }
    widget.returnType(selectionType, widget.identifier);
  }

  @override
  Widget build(BuildContext context) {
    final List<String> optionsList = widget.fields ?? types;

    if (optionsList.isEmpty) {
      return Container(
        width: widget.boxWidth,
        height: widget.boxHeight > 0 ? widget.boxHeight : 50,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: const Color.fromARGB(255, 87, 143, 134),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "No options available",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    if (selectedType == null || !optionsList.contains(selectedType)) {
      selectedType = optionsList[0];
    }

    return Container(
      width: widget.boxWidth,
      height: widget.boxHeight > 0 ? widget.boxHeight : null,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color.fromARGB(255, 87, 143, 134),
          width: 1.5,
        ),
      ),
      child: DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          isDense: true,
          contentPadding:
              EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
          border: InputBorder.none,
        ),
        value: selectedType,
        hint: Text(
          widget.backText,
          textAlign: TextAlign.left,
        ),
        items: optionsList.map((String option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(option),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            updateSelectedType(newValue);
          }
        },
        isExpanded: true,
        alignment: Alignment.centerLeft,
      ),
    );
  }
}
