import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Model/page_template.dart';
import 'package:my_ventory_mobile/View/MainPages/abstract_items_add_edit.dart';

class AddItemPage extends PageTemplate {
  const AddItemPage({super.key});

  @override
  PageTemplateState<AddItemPage> createState() => AddItemPageState();
}

class AddItemPageState extends PageTemplateState<AddItemPage> {
  @override
  Widget pageBody(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args != {}) {
      final Map<String, dynamic> safeArgs = Map<String, dynamic>.from(args);
      if (safeArgs.isEmpty) {
        return AbstractItemsAddEdit();
      } else {
        return AbstractItemsAddEdit(
          externalItem: safeArgs["item"],
          externalAttr: safeArgs["attributes"],
        );
      }
    }
    return AbstractItemsAddEdit();
  }
}
