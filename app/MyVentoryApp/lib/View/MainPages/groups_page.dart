import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Controller/group_controller.dart';
import 'package:my_ventory_mobile/Controller/single_choice_segmented_button.dart';
import 'package:my_ventory_mobile/Controller/myventory_search_bar.dart';
import 'package:my_ventory_mobile/Model/group.dart';
import 'package:my_ventory_mobile/View/MainPages/abstract_pages_view.dart.dart';
import 'package:my_ventory_mobile/View/Groups/group_view_page.dart';
import 'package:my_ventory_mobile/View/Groups/create_group_page.dart';
import 'package:my_ventory_mobile/API_authorizations/auth_service.dart';

class GroupsPage extends AbstractPagesView {
  const GroupsPage({super.key});

  @override
  AbstractPagesViewState<GroupsPage> createState() => GroupsPageState();
}

class GroupsPageState extends AbstractPagesViewState<GroupsPage>
    with SingleTickerProviderStateMixin {
  final GroupController _groupController = GroupController();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  List<Group> _myGroups = [];
  List<Group> _publicGroups = [];
  List<Group> _filteredMyGroups = [];
  List<Group> _filteredPublicGroups = [];
  bool _isLoading = false;
  // Keeping this for future implementation
  // ignore: unused_field
  String _sortBy = 'name';
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Public', 'Private'];

  @override
  List<String> get createdAttributes => ['Group', 'Group'];

  @override
  List<SegmentOption> get segmentedButtonOptions => [
        SegmentOption(label: 'My Groups', icon: Icons.group),
        SegmentOption(label: 'Public Groups', icon: Icons.public),
      ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserIdAndLoadGroups();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (userId != null && _myGroups.isEmpty && !_isLoading) {
      _loadGroups();
    } else if (userId == null) {
      _initializeUserId();
    }
  }

  Future<void> _initializeUserId() async {
    try {
      final id = await AuthService.getUserId();
      if (mounted) {
        setState(() {
          userId = id;
          if (_myGroups.isEmpty && !_isLoading) {
            _loadGroups();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting user ID: $e')),
        );
      }
    }
  }

  void _checkUserIdAndLoadGroups() {
    if (mounted) {
      if (userId != null) {
        _loadGroups();
      } else {
        Future.delayed(Duration(milliseconds: 100), () {
          _checkUserIdAndLoadGroups();
        });
      }
    }
  }

  Future<void> _loadGroups() async {
    if (userId == null || userId! <= 0) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final groups = isFirstSegment
          ? await _groupController.getMyGroups(userId!)
          : await _groupController.getPublicGroups();

      if (mounted) {
        setState(() {
          if (isFirstSegment) {
            _myGroups = groups;
            _filteredMyGroups = _myGroups;
          } else {
            _publicGroups = groups;
            _filteredPublicGroups = _publicGroups;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading groups: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Keeping this for future implementation
  // ignore: unused_element
  void _handleSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMyGroups = _myGroups;
        _filteredPublicGroups = _publicGroups;
      } else {
        _filteredMyGroups = _myGroups
            .where((group) =>
                group.name.toLowerCase().contains(query.toLowerCase()) ||
                group.description.toLowerCase().contains(query.toLowerCase()) ||
                group.members.any((member) =>
                    member.username
                        .toLowerCase()
                        .contains(query.toLowerCase()) ||
                    member.firstName
                        .toLowerCase()
                        .contains(query.toLowerCase()) ||
                    member.lastName
                        .toLowerCase()
                        .contains(query.toLowerCase())))
            .toList();

        _filteredPublicGroups = _publicGroups
            .where((group) =>
                group.name.toLowerCase().contains(query.toLowerCase()) ||
                group.description.toLowerCase().contains(query.toLowerCase()) ||
                group.members.any((member) =>
                    member.username
                        .toLowerCase()
                        .contains(query.toLowerCase()) ||
                    member.firstName
                        .toLowerCase()
                        .contains(query.toLowerCase()) ||
                    member.lastName
                        .toLowerCase()
                        .contains(query.toLowerCase())))
            .toList();
      }
    });
  }

  // Keeping this for future implementation
  // ignore: unused_element
  void _handleSort(String field, bool ascending) {
    setState(() {
      _sortBy = field;

      int compareGroups(Group a, Group b) {
        int result;
        switch (field) {
          case 'name':
            result = a.name.compareTo(b.name);
            break;
          case 'createdAt':
            result = a.createdAt.compareTo(b.createdAt);
            break;
          default:
            result = a.name.compareTo(b.name);
        }
        return ascending ? result : -result;
      }

      _filteredMyGroups.sort(compareGroups);
      _filteredPublicGroups.sort(compareGroups);
    });
  }

  @override
  void toggleView() {
    super.toggleView();
    _loadGroups();
  }

  // Override the default navigation behavior from AbstractPagesViewState
  @override
  Widget addElementInListButton(BuildContext context, String createdAttribute) {
    if (createdAttribute == "") {
      return SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            foregroundColor: const Color.fromARGB(255, 51, 75, 71),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding:
                const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
          ),
          onPressed: () => _navigateToCreateGroup(context),
          icon: const Icon(Icons.edit_outlined),
          label: Text(
            "Create a new $createdAttribute",
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }

  void _navigateToCreateGroup(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateGroupPage(userId: userId!),
      ),
    ).then((value) {
      if (value == true) {
        _loadGroups();
      }
    });
  }

  @override
  Widget pageBody(BuildContext context) {
    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final displayedGroups =
        isFirstSegment ? _filteredMyGroups : _filteredPublicGroups;

    return Align(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 30.0, left: 8.0, right: 8.0),
            child: SingleChoiceSegmentedButton(
                onSegmentButtonChange: toggleView,
                options: segmentedButtonOptions),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    child: MyventorySearchBar(
                      userId: userId!,
                      onSearch: handleSearch,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: DropdownButton<String>(
                      value: _selectedFilter,
                      dropdownColor: Colors.white,
                      icon: const Icon(Icons.arrow_drop_down,
                          color: Color.fromARGB(255, 51, 75, 71)),
                      underline: Container(),
                      items: _filterOptions.map((String filter) {
                        return DropdownMenuItem<String>(
                          value: filter,
                          child: Text(
                            filter,
                            style: const TextStyle(
                              color: Color.fromARGB(255, 51, 75, 71),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedFilter = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          addElementInListButton(context,
              isFirstSegment ? createdAttributes[0] : createdAttributes[1]),
          const Padding(padding: EdgeInsets.symmetric(vertical: 5.0)),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: displayedGroups.where((group) {
                  final matchesSearch = group.name
                          .toLowerCase()
                          .contains(currentSearchQuery.toLowerCase()) ||
                      group.description
                          .toLowerCase()
                          .contains(currentSearchQuery.toLowerCase());

                  final matchesFilter = _selectedFilter == 'All' ||
                      (_selectedFilter == 'Public' &&
                          group.privacy == GroupPrivacy.public) ||
                      (_selectedFilter == 'Private' &&
                          group.privacy == GroupPrivacy.private);

                  return matchesSearch && matchesFilter;
                }).map((group) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              GroupViewPage(groupId: group.groupId.toString()),
                        ),
                      ).then((_) => _loadGroups());
                    },
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.rectangle,
                        border: Border(
                          top: BorderSide(
                              color: Color.fromARGB(255, 203, 214, 210)),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            // Group profile picture
                            CircleAvatar(
                              radius: 30,
                              backgroundImage: group.groupProfilePicture != null
                                  ? MemoryImage(group.groupProfilePicture!)
                                  : const AssetImage(
                                          'assets/default_profile.jpg')
                                      as ImageProvider,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    group.description,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        group.privacy == GroupPrivacy.public
                                            ? Icons.public
                                            : Icons.lock,
                                        size: 16,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        group.privacy == GroupPrivacy.public
                                            ? 'Public'
                                            : 'Private',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Icon(
                                        Icons.people,
                                        size: 16,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${group.members.length} members',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (isFirstSegment)
                              const Icon(Icons.arrow_forward_ios,
                                  color: Colors.white)
                            else if (!_myGroups
                                .any((g) => g.groupId == group.groupId))
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color.fromARGB(255, 51, 75, 71),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () async {
                                  try {
                                    await _groupController.joinGroup(
                                        userId!, group.groupId);
                                    // ignore: use_build_context_synchronously
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Successfully joined the group!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    _loadGroups();
                                  } catch (e) {
                                    // ignore: use_build_context_synchronously
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Failed to join group: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Join'),
                              )
                            else
                              const SizedBox.shrink()
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // This is not overriding any parent method
  String get pageTitle => 'Groups';
}
