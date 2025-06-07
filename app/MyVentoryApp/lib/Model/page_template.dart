import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Controller/external.dart';
import 'package:my_ventory_mobile/Model/clear_text_button.dart';
import 'package:my_ventory_mobile/Model/overlay_feature.dart';
import 'package:my_ventory_mobile/Model/shortcut_action.dart';
import 'package:my_ventory_mobile/Model/shortcut_item.dart';
import 'package:my_ventory_mobile/Model/text_boxes.dart';
import 'package:my_ventory_mobile/View/picture_page.dart';

abstract class PageTemplate extends StatefulWidget {
  const PageTemplate({super.key});

  @override
  PageTemplateState<PageTemplate> createState();
}

abstract class PageTemplateState<T extends PageTemplate> extends State<T> {
  late final List<ShortcutAction> actions;

  List<TextEditingController> t = [];
  List<GlobalKey<TextBoxState>> k = [];
  List<ClearTextButton> c = [];

  OverlayEntry? oe;

  final ApiService as = ApiService();

  @override
  void initState() {
    super.initState();
    actions = [
      ShortcutAction(
        value: 6,
        icon: Icons.edit_note,
        text: 'Add manually',
        action: () {
          final navigator = Navigator.of(context);

          navigator.pushNamed(
            '/add',
            arguments: {},
          );
        },
      ),
      if (!kIsWeb)
        ShortcutAction(
          value: 2,
          icon: Icons.barcode_reader,
          text: 'Scan barcode',
          action: () async {
            shortcutAction(context, "SCAN_BARCODE", true);
          },
        ),
      if (!kIsWeb)
        ShortcutAction(
          value: 0,
          icon: Icons.category,
          text: 'Scan object',
          action: () async {
            shortcutAction(context, "GENERAL_IMAGE", true);
          },
        ),
      if (!kIsWeb)
        ShortcutAction(
          value: 1,
          icon: Icons.book_rounded,
          text: 'Scan book',
          action: () async {
            shortcutAction(context, "SCAN_BOOK", true);
          },
        ),
      ShortcutAction(
        value: 3,
        icon: Icons.book_rounded,
        text: 'Search book',
        action: () async {
          shortcutAction(context, "SEARCH_AUTHOR_TITLE", false);
        },
      ),
      if (!kIsWeb)
        ShortcutAction(
          value: 4,
          icon: Icons.disc_full,
          text: 'Scan album',
          action: () async {
            shortcutAction(context, "SCAN_ALBUM", true);
          },
        ),
      ShortcutAction(
        value: 5,
        icon: Icons.disc_full,
        text: 'Search album',
        action: () async {
          shortcutAction(context, "SEARCH_ALBUM", false);
        },
      )
    ];
  }

  void shortcutAction(BuildContext context, String duty, bool withImage) async {
    bool quitOnPurpose;
    Uint8List imgToExternal = Uint8List(0);

    if (withImage) {
      List<String> pickedPaths =
          await PicturePage.showImageSourceDialog(context);
      if (pickedPaths != []) {
        imgToExternal = await File(pickedPaths.first).readAsBytes();
        quitOnPurpose = false;
      } else {
        quitOnPurpose = true;
      }
    } else {
      Completer<bool> completer = Completer<bool>();

      for (var i = 0; i < 2; i++) {
        TextEditingController tec = TextEditingController();
        GlobalKey<TextBoxState> key = GlobalKey<TextBoxState>();
        ClearTextButton ctb = ClearTextButton(textBoxKey: key, boxC: tec);
        t.add(tec);
        k.add(key);
        c.add(ctb);
      }

      OverlayFeature.displayTextEntryOverlay(
          context, duty, oe, t, k, c, completer);

      quitOnPurpose = await completer.future;
    }

    if (!(quitOnPurpose)) {
      final NavigatorState? navigator;
      if (context.mounted) {
        navigator = Navigator.of(context);
      } else {
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      Map<String, dynamic> i;
      if (duty == "SEARCH_ALBUM") {
        i = await as.searchExternalInventory(
            requestType: duty, query: t[0].text);
      } else if (duty == "SEARCH_AUTHOR_TITLE") {
        i = await as.searchExternalInventory(
            requestType: duty, author: t[0].text, title: t[1].text);
      } else {
        i = await as.searchExternalInventory(
            requestType: duty, imageBytes: imgToExternal);
      }

      navigator.pop();

      if (i.isNotEmpty) {
        navigator.pushNamed(
          '/add',
          arguments: {'item': i['item'], 'attributes': i['attributes']},
        );
      } else {
        if (context.mounted) OverlayFeature.displayMessageOverlay(context, false, "Nothing was found");
        for (var i = 0; i < t.length; i++) {
          t[i].text = "";
        }
      }
    }
  }

  // ==========================================================================
  // Abstract method used by childerens to create their own version of the body.
  Widget pageBody(BuildContext context);
  // ==========================================================================

  // ==========================================================================
  // Widgets used to build to bottom navigation bar
  Widget buildNavigationBar(BuildContext context) {
    return NavigationBar(
      backgroundColor: const Color.fromARGB(255, 233, 239, 236),
      destinations: [
        buildNavButton(context, '/inventory', Icons.shelves, 'Inventory'),
        buildNavButton(context, '/groups', Icons.groups, 'Groups'),
        buildNavPopupButton(context, actions, redirection, '/add',
            Icons.add_circle_outline, 'Add'),
        buildNavButton(
            context, '/lendings', Icons.people_alt_rounded, 'Sharing'),
        buildNavButton(context, '/account', Icons.account_circle, 'Account'),
      ],
    );
  }

  Widget buildNavButton(
      BuildContext context, String route, IconData icon, String label) {
    bool isActive = ModalRoute.of(context)?.settings.name == route;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: SizedBox(
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: const Color.fromARGB(255, 51, 75, 71),
                backgroundColor: Colors.transparent,
                shadowColor: isActive
                    ? const Color.fromARGB(100, 202, 230, 223)
                    : Colors.transparent,
                minimumSize: const Size(40, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => Navigator.pushNamed(context, route),
              child: Icon(icon, size: 20),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildNavPopupButton(BuildContext context, List<ShortcutAction> sa,
      Function(int) redirection, String route, IconData icon, String label) {
    bool isActive = ModalRoute.of(context)?.settings.name == route;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: SizedBox(
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PopupMenuButton<int>(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: const Color.fromARGB(255, 51, 75, 71),
                backgroundColor: Colors.transparent,
                shadowColor: isActive
                    ? const Color.fromARGB(100, 202, 230, 223)
                    : Colors.transparent,
                minimumSize: const Size(40, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(icon, size: 20),
              onSelected: (item) => redirection(item),
              itemBuilder: (context) => sa.map((menuAction) {
                return ShortcutItem(
                  value: menuAction.value,
                  icon: menuAction.icon,
                  text: menuAction.text,
                );
              }).toList(),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
  // ==========================================================================

  // ==========================================================================
  // Widget to build the ShortcutButton to get directly access to camera and then to the "add item page"

  void redirection(int item) {
    final action =
        actions.firstWhere((menuAction) => menuAction.value == item).action;
    action();
  }
  // ==========================================================================

  // ==========================================================================
  // Build widget of the abstract class
  @override
  Widget build(BuildContext context) {
    bool isItemPage = ModalRoute.of(context)?.settings.name == '/item';

    return Scaffold(
        backgroundColor: const Color.fromARGB(255, 131, 184, 175),
        bottomNavigationBar: isItemPage ? null : buildNavigationBar(context),
        body: Stack(
          children: [
            pageBody(context),
          ],
        ));
  }
  // ==========================================================================
}
