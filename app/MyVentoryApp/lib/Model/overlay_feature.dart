import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Model/clear_text_button.dart';
import 'package:my_ventory_mobile/Model/text_boxes.dart';

class OverlayFeature {
  static final RouteObserver<ModalRoute> routeObserver =
      RouteObserver<ModalRoute>();

  static OverlayEntry displayOverlay(
      BuildContext context, List<Widget> overlayContent, int pixelsFromTop) {
    OverlayEntry entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: () {},
            child: Container(
              color: Color.fromRGBO(0, 0, 0, 0.2),
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height / 2 - pixelsFromTop,
            left: MediaQuery.of(context).size.width / 6,
            right: MediaQuery.of(context).size.width / 6,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: overlayContent,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Navigator.of(context).overlay?.insert(entry);

    return entry;
  }

  static void displayMessageOverlay(
      BuildContext context, bool hasWorked, String dedicatedText) {
    OverlayEntry? oE;

    List<Widget> content = [
      GestureDetector(
        onTap: () {
          oE?.remove();
          oE = null;
        },
        child: Container(
          color: Colors.transparent,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: hasWorked
                  ? [
                      Icon(Icons.check_circle, color: Colors.green, size: 100),
                      SizedBox(width: 8),
                      Text(
                        dedicatedText,
                        style: TextStyle(color: Colors.black, fontSize: 20),
                      ),
                    ]
                  : [
                      Icon(Icons.cancel_outlined, color: Colors.red, size: 100),
                      SizedBox(width: 8),
                      Text(
                        dedicatedText,
                        style: TextStyle(color: Colors.black, fontSize: 20),
                      ),
                    ],
            ),
          ),
        ),
      ),
    ];

    oE = displayOverlay(context, content, 50);

    Future.delayed(Duration(seconds: 3), () {
      oE?.remove();
      oE = null;
    });
  }

  static List<Widget> textEntryWidgets(BuildContext context, String duty,
      TextEditingController t, GlobalKey<TextBoxState> k, ClearTextButton c) {
    return [
      Text(duty),
      Padding(padding: EdgeInsets.symmetric(vertical: 5.0)),
      TextBox(
        key: k,
        backText: 'Search...',
        featureButton: c,
        boxC: t,
        boxWidth: (MediaQuery.of(context).size.width) * (4 / 6) - 20,
      ),
    ];
  }

  static void displayTextEntryOverlay(
      BuildContext context,
      String researchDuty,
      OverlayEntry? oE,
      List<TextEditingController> tc,
      List<GlobalKey<TextBoxState>> keys,
      List<ClearTextButton> ctbs,
      Completer<bool> onSubmit) {
    List<Widget> content = <Widget>[
      Align(
        alignment: Alignment(1, 0),
        child: IconButton(
          icon: const Icon(Icons.cancel, color: Colors.red),
          onPressed: () {
            oE?.remove();
            onSubmit.complete(true);
          },
        ),
      ),
      ...({
            'SEARCH_AUTHOR_TITLE': [
              Text("Search with author name and/or book title"),
              Padding(padding: EdgeInsets.symmetric(vertical: 5.0)),
              ...textEntryWidgets(context, "Author", tc[0], keys[0], ctbs[0]),
              Padding(padding: EdgeInsets.symmetric(vertical: 2.0)),
              ...textEntryWidgets(context, "Title", tc[1], keys[1], ctbs[1])
            ],
            'SEARCH_ALBUM': textEntryWidgets(
                context, "Search with album title", tc[0], keys[0], ctbs[0]),
          }[researchDuty] ??
          <Widget>[]),
      SizedBox(height: 10),
      ElevatedButton(
        onPressed: () {
          oE?.remove();
          onSubmit.complete(false);
        },
        child: Text("Submit"),
      ),
    ];

    oE = displayOverlay(context, content, 150);
  }
}
