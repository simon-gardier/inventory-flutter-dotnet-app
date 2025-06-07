import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Controller/filters_list.dart';
import 'package:my_ventory_mobile/Controller/myventory_search_bar.dart';
import 'package:my_ventory_mobile/Controller/single_choice_segmented_button.dart';
import 'package:my_ventory_mobile/Controller/vertical_elements_list.dart';
import 'package:my_ventory_mobile/Model/page_template.dart';
import 'package:my_ventory_mobile/API_authorizations/auth_service.dart';

abstract class AbstractPagesView extends PageTemplate {
  const AbstractPagesView({super.key});

  @override
  PageTemplateState<AbstractPagesView> createState();
}

abstract class AbstractPagesViewState<T extends AbstractPagesView>
    extends PageTemplateState<T> {
  bool isFirstSegment = true;
  String currentSearchQuery = '';
  int? userId;
  bool isLoading = true;

  List<SegmentOption> get segmentedButtonOptions;
  List<String> get createdAttributes;

  @override
  void initState() {
    super.initState();
    loadUserId();
  }

  Future<void> loadUserId() async {
    try {
      final id = await AuthService.getUserId();

      if (mounted) {
        setState(() {
          userId = id;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void toggleView() {
    setState(() {
      isFirstSegment = !isFirstSegment;
    });
  }

  void handleSearch(String query) {
    setState(() {
      currentSearchQuery = query;
    });
  }

  Widget addElementInListButton(BuildContext context, String createdAttribute) {
    if (createdAttribute == "") {
      return SizedBox.shrink();
    }
    return SizedBox(
      width: MediaQuery.of(context).size.width * 4 / 5,
      height: MediaQuery.of(context).size.height * 0.8 / 10,
      child: Align(
        alignment: Alignment.center,
        child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: const Color.fromARGB(255, 51, 75, 71),
              backgroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pushNamed(context, '/add'),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.edit_outlined, size: 20),
              Padding(padding: EdgeInsets.symmetric(horizontal: 7.0)),
              Text("Create a new $createdAttribute",
                  style: const TextStyle(fontSize: 15)),
            ])),
      ),
    );
  }

  @override
  Widget pageBody(BuildContext context) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    return Align(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: EdgeInsets.symmetric(vertical: 20.0)),
          SingleChoiceSegmentedButton(
              onSegmentButtonChange: toggleView,
              options: segmentedButtonOptions),
          MyventorySearchBar(
            userId: userId ?? -1,
            onSearch: handleSearch,
          ),
          if (isFirstSegment) FiltersList(),
          addElementInListButton(
              context,
              createdAttributes.length > 1
                  ? (isFirstSegment
                      ? createdAttributes[0]
                      : createdAttributes[1])
                  : ""),
          Padding(padding: EdgeInsets.symmetric(vertical: 5.0)),
          Expanded(
              child: VerticalElementsList(
            userId: userId ?? -1,
            isFirstOption: isFirstSegment,
            searchQuery: currentSearchQuery,
            isLoading: isLoading,
          )),
        ],
      ),
    );
  }
}
