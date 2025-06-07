import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Model/clear_text_button.dart';
import 'package:my_ventory_mobile/Model/multiple_choice_button.dart';
import 'package:my_ventory_mobile/Model/text_boxes.dart';

class AttributeRow extends StatefulWidget {
  final int attributeIndex;
  final TextEditingController nameController;
  final TextEditingController valueController;
  final GlobalKey<TextBoxState> nameKey;
  final GlobalKey<TextBoxState> valueKey;
  final ClearTextButton nameCtb;
  final ClearTextButton valueCtb;
  final Function(String, int) getDataFromType;
  final String initialType;

  const AttributeRow({
    super.key,
    required this.attributeIndex,
    required this.nameController,
    required this.valueController,
    required this.nameKey,
    required this.valueKey,
    required this.nameCtb,
    required this.valueCtb,
    required this.getDataFromType,
    this.initialType = '',
  });

  @override
  State<AttributeRow> createState() => _AttributeRowState();
}

class _AttributeRowState extends State<AttributeRow> {
  String currentType = '';
  bool isDatePickerOpen = false;
  final TextEditingController dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    currentType = widget.initialType;

    // Handle initial value formatting based on type
    if (currentType == 'Date' && widget.valueController.text.isNotEmpty) {
      try {
        final dateValue = DateTime.parse(widget.valueController.text);
        // Format date manually without intl package
        final month = dateValue.month.toString().padLeft(2, '0');
        final year = dateValue.year.toString();
        dateController.text = "$month/$year";
      } catch (e) {
        dateController.text = widget.valueController.text;
      }
    }

    if (currentType == 'Currency' && widget.valueController.text.isNotEmpty) {
      try {
        // Remove € symbol if present for parsing
        String valueText = widget.valueController.text;
        if (valueText.startsWith('€')) {
          valueText = valueText.substring(1);
        }
        final value = double.parse(valueText);
        widget.valueController.text = '€${value.toStringAsFixed(2)}';
      } catch (e) {
        // Keep original if parsing fails
      }
    }
  }

  @override
  void dispose() {
    dateController.dispose();
    super.dispose();
  }

  void _handleTypeChange(String type, int index) {
    setState(() {
      currentType = type;

      // Reset value when changing types
      if (type == 'Category') {
        widget.valueController.text = 'N/A';
      } else if (type == 'Date') {
        final now = DateTime.now();
        widget.valueController.text = now.toIso8601String();
        // Format date manually without intl package
        final month = now.month.toString().padLeft(2, '0');
        final year = now.year.toString();
        dateController.text = "$month/$year";
      } else if (type == 'Number') {
        widget.valueController.text = '0';
      } else if (type == 'Currency') {
        widget.valueController.text = '€0.00';
      } else {
        // For Text and Link types
        widget.valueController.text = '';
      }
    });

    widget.getDataFromType(type, index);
  }

  // Helper to open date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime initialDate = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      // Simplify to just show month and year
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      setState(() {
        // Format date manually without intl package
        final month = picked.month.toString().padLeft(2, '0');
        final year = picked.year.toString();
        dateController.text = "$month/$year";
        widget.valueController.text =
            picked.toIso8601String(); // Store as ISO format
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name field
        TextBox(
          key: widget.nameKey,
          backText: 'Name',
          featureButton: widget.nameCtb,
          boxC: widget.nameController,
          boxWidth: (MediaQuery.of(context).size.width - 40),
        ),
        const Padding(padding: EdgeInsets.symmetric(vertical: 4.0)),
        Row(
          children: [
            // Type Dropdown
            MultipleChoiceButton(
              backText: 'Type',
              boxWidth:
                  (MediaQuery.of(context).size.width - 40) * (1 / 2) - 3.0,
              returnType: _handleTypeChange,
              identifier: widget.attributeIndex,
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 3.0)),
            // Value field - changes based on type
            _buildValueField(),
          ],
        ),
      ],
    );
  }

  Widget _buildValueField() {
    final width = (MediaQuery.of(context).size.width - 40) * (1 / 2) - 3.0;

    switch (currentType) {
      case 'Category':
        return Container(
          width: width,
          height: 45, // Reduced height
          decoration: BoxDecoration(
            color: Colors.grey[200],
            border: Border.all(
              color: const Color.fromARGB(255, 87, 143, 134),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
          alignment: Alignment.centerLeft,
          child: const Text('N/A',
              style: TextStyle(color: Colors.grey, fontSize: 14)),
        );

      case 'Date':
        return GestureDetector(
          onTap: () => _selectDate(context),
          child: Container(
            width: width,
            height: 45, // Reduced height
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: const Color.fromARGB(255, 87, 143, 134),
                width: 1.5,
              ),
            ),
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateController.text.isEmpty ? 'MM/YYYY' : dateController.text,
                  style: TextStyle(
                    color: dateController.text.isEmpty
                        ? Colors.grey
                        : Colors.black,
                    fontSize: 14,
                  ),
                ),
                const Icon(Icons.calendar_today, size: 16),
              ],
            ),
          ),
        );

      case 'Number':
        return TextBox(
          key: widget.valueKey,
          backText: 'Value',
          featureButton: widget.valueCtb,
          boxC: widget.valueController,
          boxWidth: width,
        );

      case 'Currency':
        return TextBox(
          key: widget.valueKey,
          backText: 'Value (€)',
          featureButton: widget.valueCtb,
          boxC: widget.valueController,
          boxWidth: width,
        );

      case 'Link':
        return TextBox(
          key: widget.valueKey,
          backText: 'URL',
          featureButton: widget.valueCtb,
          boxC: widget.valueController,
          boxWidth: width,
        );

      case 'Text':
      default:
        return TextBox(
          key: widget.valueKey,
          backText: 'Value',
          featureButton: widget.valueCtb,
          boxC: widget.valueController,
          boxWidth: width,
        );
    }
  }
}
