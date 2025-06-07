import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_ventory_mobile/Model/clear_text_button.dart';

class TextBox extends StatefulWidget {
  final String backText;
  final Widget? featureButton;
  final bool obscureTxtFt;
  final TextEditingController boxC;
  final double boxWidth;
  final double boxHeight;
  final Map<String, String>? suggestions;
  final void Function(String)? onSuggestionSelected;

  const TextBox(
      {super.key,
      required this.backText,
      this.featureButton,
      bool? obscureTxtFt,
      required this.boxC,
      required this.boxWidth,
      double? boxHeight,
      this.suggestions,
      this.onSuggestionSelected})
      : obscureTxtFt = obscureTxtFt ?? false,
        boxHeight = boxHeight ?? 0;

  @override
  State<TextBox> createState() => TextBoxState();
}

class TextBoxState extends State<TextBox> {
  bool isObscureText = true;
  bool neverObscure = false;

  void toggleObscure() {
    setState(() {
      isObscureText = !isObscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool hasSuggestions = (widget.suggestions?.isNotEmpty ?? false);

    final InputDecoration floatingLabelDecoration = InputDecoration(
      labelText: widget.backText,
      labelStyle: TextStyle(color: Color(0xFF3A605B).withAlpha(204)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Color(0xFF4F8079)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Color(0xFF4F8079)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Color(0xFF4F8079), width: 1.5),
      ),
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
      suffixIcon: widget.featureButton,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: widget.boxWidth,
          height: widget.boxHeight > 0 ? widget.boxHeight : null,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.zero,
            child: hasSuggestions
                ? Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return widget.suggestions!.keys.toList();
                        // return suggestions;
                      }
                      return widget.suggestions!.keys
                          .toList()
                          .where((String option) {
                        // return suggestions.where((String option) {
                        return option
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    fieldViewBuilder: (BuildContext context,
                        TextEditingController textEditingController,
                        FocusNode focusNode,
                        VoidCallback onFieldSubmitted) {
                      if (widget.boxC.text != textEditingController.text) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          textEditingController.text = widget.boxC.text;
                          textEditingController.selection =
                              TextSelection.fromPosition(TextPosition(
                                  offset: textEditingController.text.length));
                        });
                      }

                      void syncControllersListener() {
                        syncControllers(textEditingController);
                      }

                      textEditingController
                          .removeListener(syncControllersListener);
                      textEditingController
                          .addListener(syncControllersListener);

                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        textInputAction: TextInputAction.search,
                        obscureText:
                            widget.obscureTxtFt ? isObscureText : neverObscure,
                        decoration: floatingLabelDecoration,
                        maxLines: 1,
                      );
                    },
                    optionsViewBuilder: (BuildContext context,
                        AutocompleteOnSelected<String> onSelected,
                        Iterable<String> options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          child: Container(
                            width: widget.boxWidth,
                            constraints: BoxConstraints(
                              maxHeight: 200,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              color: Colors.white,
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final String option = options.elementAt(index);
                                return ListTile(
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    onSelected: (String selection) {
                      widget.boxC.text = selection;
                      if (widget.onSuggestionSelected != null) {
                        String selectionType = widget.suggestions![selection]!;
                        widget.onSuggestionSelected!(selectionType);
                      }
                    },
                  )
                : TextField(
                    controller: widget.boxC,
                    obscureText:
                        widget.obscureTxtFt ? isObscureText : neverObscure,
                    decoration: floatingLabelDecoration,
                    maxLines: 1,
                  ),
          ),
        ),
      ],
    );
  }

  // Method to sync controllers to avoid issues
  void syncControllers(TextEditingController autocompleteController) {
    if (widget.boxC.text != autocompleteController.text) {
      widget.boxC.text = autocompleteController.text;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class StaticTextBox extends StatelessWidget {
  final String label;
  final double width;
  final double height;
  final Widget childText;

  const StaticTextBox(
      {super.key,
      required this.label,
      required this.width,
      double? height,
      required this.childText})
      : height = height ?? 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: width,
          height: height > 0 ? height : null,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: const Color.fromARGB(255, 87, 143, 134),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          alignment: Alignment.centerLeft,
          child: childText,
        ),
      ],
    );
  }
}

class FormattedTextBox extends StatelessWidget {
  final GlobalKey<TextBoxState> textBoxKey;
  final ClearTextButton? featureButton;
  final TextEditingController boxC;
  final String? backText;
  final double boxWidth;
  final double? boxHeight;
  final int? maxLines;
  final BoxConstraints? constr;
  final InputDecoration? textFieldDeco;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;

  const FormattedTextBox({
    super.key,
    required this.textBoxKey,
    this.featureButton,
    required this.boxC,
    this.backText,
    required this.boxWidth,
    this.boxHeight,
    this.maxLines,
    this.constr,
    this.textFieldDeco,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.prefixText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: boxWidth,
      height: boxHeight,
      constraints: constr,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color.fromARGB(255, 87, 143, 134),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: boxC,
        decoration: textFieldDeco ??
            InputDecoration(
              border: InputBorder.none,
              hintText: backText,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
              suffixIcon: featureButton,
              prefixText: prefixText,
              prefixStyle: const TextStyle(color: Colors.black, fontSize: 16),
            ),
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
      ),
    );
  }
}

class ValuesTextBox extends StatefulWidget {
  final ValueNotifier<String> typeNotifier;
  final TextEditingController tc;
  final GlobalKey<TextBoxState> textboxkey;
  final ClearTextButton ctb;

  const ValuesTextBox(
      {super.key,
      required this.typeNotifier,
      required this.tc,
      required this.textboxkey,
      required this.ctb});

  @override
  State<ValuesTextBox> createState() => ValuesTextBoxState();
}

class ValuesTextBoxState extends State<ValuesTextBox> {
  // Create popup to make the user choose its desired date
  Future<void> selectDate() async {
    final DateTime now = DateTime.now();
    DateTime? initialDate;

    if (widget.tc.text.isNotEmpty) {
      initialDate = parseDate(widget.tc.text);
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color.fromARGB(255, 0, 107, 96),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        widget.tc.text =
            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  // Mehtod to change a string into a DateTime
  DateTime? parseDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);

        if (day >= 1 &&
            day <= 31 &&
            month >= 1 &&
            month <= 12 &&
            year >= 2000) {
          return DateTime(year, month, day);
        }
      }
    } catch (e) {
      throw Exception("The date currently saved is not changeable in DateTime");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
        valueListenable: widget.typeNotifier,
        builder: (context, type, child) {
          switch (type) {
            case "Date":
              return GestureDetector(
                onTap: () => selectDate(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: const Color.fromARGB(255, 87, 143, 134),
                      width: 1.5,
                    ),
                  ),
                  height: 50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12.0),
                          child: Text(
                            widget.tc.text.isEmpty
                                ? "Select Date"
                                : widget.tc.text,
                            style: TextStyle(
                              fontSize: 16,
                              color: widget.tc.text.isEmpty
                                  ? Colors.grey
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.calendar_today,
                          color: const Color.fromARGB(255, 87, 143, 134),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              );

            case "Number":
              return FormattedTextBox(
                textBoxKey: widget.textboxkey,
                backText: 'Value',
                featureButton: widget.ctb,
                boxC: widget.tc,
                boxWidth: double.infinity,
                boxHeight: 50,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    if (newValue.text.isEmpty) {
                      return newValue;
                    }

                    if (RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(newValue.text)) {
                      if (newValue.text.contains('.')) {
                        List<String> parts = newValue.text.split('.');
                        if (parts[0].length > 1 && parts[0].startsWith('0')) {
                          parts[0] = parts[0].replaceFirst(RegExp(r'^0+'), '');
                          parts[0] = parts[0].isEmpty ? '0' : parts[0];
                          return TextEditingValue(
                            text: '${parts[0]}.${parts[1]}',
                            selection: TextSelection.collapsed(
                                offset: parts[0].length + parts[1].length + 1),
                          );
                        }
                      } else if (newValue.text.length > 1 &&
                          newValue.text.startsWith('0')) {
                        String newText =
                            newValue.text.replaceFirst(RegExp(r'^0+'), '');
                        return TextEditingValue(
                          text: newText,
                          selection:
                              TextSelection.collapsed(offset: newText.length),
                        );
                      }
                      return newValue;
                    }
                    return oldValue;
                  }),
                ],
              );

            case "Currency":
              return FormattedTextBox(
                textBoxKey: widget.textboxkey,
                backText: 'Value',
                featureButton: widget.ctb,
                boxC: widget.tc,
                boxWidth: double.infinity,
                boxHeight: 50,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    if (newValue.text.isEmpty) {
                      return newValue;
                    }

                    String textToValidate =
                        newValue.text.replaceAll('€', '').trim();

                    if (RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(textToValidate)) {
                      if (textToValidate.contains('.')) {
                        List<String> parts = textToValidate.split('.');
                        if (parts[0].length > 1 && parts[0].startsWith('0')) {
                          parts[0] = parts[0].replaceFirst(RegExp(r'^0+'), '');
                          parts[0] = parts[0].isEmpty ? '0' : parts[0];
                          return TextEditingValue(
                            text: '€${parts[0]}.${parts[1]}',
                            selection: TextSelection.collapsed(
                                offset: parts[0].length + parts[1].length + 2),
                          );
                        } else {
                          if (!newValue.text.contains('€')) {
                            return TextEditingValue(
                              text: '€$textToValidate',
                              selection: TextSelection.collapsed(
                                  offset: textToValidate.length + 1),
                            );
                          }
                        }
                      } else if (textToValidate.length > 1 &&
                          textToValidate.startsWith('0')) {
                        String newText =
                            textToValidate.replaceFirst(RegExp(r'^0+'), '');
                        return TextEditingValue(
                          text: '€$newText',
                          selection: TextSelection.collapsed(
                              offset: newText.length + 1),
                        );
                      } else if (!newValue.text.contains('€')) {
                        return TextEditingValue(
                          text: '€$textToValidate',
                          selection: TextSelection.collapsed(
                              offset: textToValidate.length + 1),
                        );
                      }
                      return newValue;
                    }
                    return oldValue;
                  }),
                ],
                prefixText: '€',
              );

            case "Category":
              return Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0x33CCCCCC),
                  border: Border.all(
                    color: const Color.fromARGB(255, 87, 143, 134),
                    width: 1.5,
                  ),
                ),
                child: const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                  child: Text(
                    "N/A - No value",
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ),
              );

            case "Link":
              return TextBox(
                key: widget.textboxkey,
                backText: 'Value (URL)',
                featureButton: widget.ctb,
                boxC: widget.tc,
                boxWidth: double.infinity,
              );

            // For exemple when new attribute or if text type
            default:
              return TextBox(
                key: widget.textboxkey,
                backText: 'Value',
                featureButton: widget.ctb,
                boxC: widget.tc,
                boxWidth: double.infinity,
              );
          }
        });
  }
}
