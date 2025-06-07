import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Model/page_template.dart';
import 'package:my_ventory_mobile/View/MainPages/abstract_items_add_edit.dart';

class ItemEditPage extends PageTemplate {
  final int itemId;

  const ItemEditPage({super.key, required this.itemId});

  @override
  PageTemplateState<ItemEditPage> createState() => ItemEditPageState();
}

class ItemEditPageState extends PageTemplateState<ItemEditPage> {
  @override
  Widget pageBody(BuildContext context) {
    return AbstractItemsAddEdit(
      itemId: widget.itemId,
    );
  }
}
