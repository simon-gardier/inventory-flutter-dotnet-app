import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Controller/group_controller.dart';
import 'package:my_ventory_mobile/Controller/single_choice_segmented_button.dart';
import 'package:my_ventory_mobile/Model/group.dart';
import 'package:my_ventory_mobile/View/MainPages/abstract_pages_view.dart.dart';
import 'package:my_ventory_mobile/Model/user.dart';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart';
import 'package:my_ventory_mobile/View/Groups/group_inventory_page.dart';
import 'package:my_ventory_mobile/View/Groups/edit_group_page.dart';
import 'dart:convert';

class GroupViewPage extends AbstractPagesView {
  final String groupId;

  const GroupViewPage({super.key, required this.groupId});

  @override
  AbstractPagesViewState<GroupViewPage> createState() => GroupViewPageState();
}

class GroupViewPageState extends AbstractPagesViewState<GroupViewPage> {
  final GroupController _groupController = GroupController();
  final ApiService _apiService = ApiService();
  Group? _group;
  bool _isLoading = false;
  bool _isOwner = false;

  List<UserAccount> _searchedUsers = [];

  @override
  List<String> get createdAttributes => [];

  @override
  List<SegmentOption> get segmentedButtonOptions => [];

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    setState(() => _isLoading = true);

    try {
      int groupIdInt;
      try {
        groupIdInt = int.parse(widget.groupId);
      } catch (e) {
        groupIdInt = 1;
      }

      final group = await _groupController.getGroupById(groupIdInt);

      if (mounted) {
        setState(() {
          _group = group;
          _isOwner = userId != null && group.isUserFounder(userId!);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading group: $e')),
        );
      }
    }
  }

  Future<void> _leaveGroup() async {
    if (userId == null || _group == null) return;

    setState(() => _isLoading = true);

    try {
      final groupId = int.parse(widget.groupId);
      final success = await _groupController.leaveGroup(userId!, groupId);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully left group')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to leave group')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error leaving group: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget pageBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_group == null) {
      return const Center(
        child: Text(
          'Group not found',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Column(
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              IconButton(
                padding: const EdgeInsets.all(16.0),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  _group!.name,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group image
                    if (_group!.groupProfilePicture != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.memory(
                      _group!.groupProfilePicture!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 120,
                        width: double.infinity,
                        color: Colors.grey[300],
                        child: const Icon(Icons.group,
                          size: 60, color: Colors.grey),
                      ),
                      ),
                    )
                    else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Container(
                      height: 120,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Icon(Icons.group,
                        size: 60, color: Colors.grey),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Group details
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _group!.name,
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _group!.description,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.people, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                '${_group!.members.length} members',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                _group!.isPublic ? Icons.public : Icons.lock,
                                color: _group!.isPublic
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _group!.isPublic
                                    ? 'Public Group'
                                    : 'Private Group',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Created: ${_formatDate(_group!.createdAt)}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.update, color: Colors.purple),
                              const SizedBox(width: 8),
                              Text(
                                'Updated: ${_formatDate(_group!.updatedAt)}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Members section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Members',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              Text('${_group!.members.length} total',
                                  style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _group!.members.length,
                            itemBuilder: (context, index) {
                              final member = _group!.members[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      _getMemberRoleColor(member.role)[0],
                                  child: Icon(
                                    Icons.person,
                                    color: _getMemberRoleColor(member.role)[1],
                                  ),
                                ),
                                title: Text(member.fullName),
                                subtitle: Text(member.username),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Chip(
                                      label: Text(
                                          _getMemberRoleLabel(member.role)),
                                      backgroundColor:
                                          _getMemberRoleColor(member.role)[0],
                                    ),
                                    if (_isOwner &&
                                        member.role != MemberRole.founder)
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle,
                                            color: Colors.red),
                                        onPressed: () =>
                                            _showRemoveMemberConfirmation(
                                                member),
                                        tooltip: 'Remove member',
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Group actions
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GroupInventoryPage(
                                      groupId: int.parse(widget.groupId)),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color.fromARGB(255, 0, 107, 96),
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'View Group Inventory',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_isOwner) ...[
                            ElevatedButton(
                              onPressed: () => _showEditGroupDialog(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Edit Group',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => _showAddMemberDialog(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Add Member',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => _showDeleteGroupConfirmation(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Delete Group',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ] else ...[
                            ElevatedButton(
                              onPressed: _leaveGroup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Leave Group',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Helper methods
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  List<Color?> _getMemberRoleColor(MemberRole role) {
    switch (role) {
      case MemberRole.founder:
        return [Colors.amber[200], Colors.amber[800]];
      case MemberRole.administrator:
        return [Colors.orange[200], Colors.orange[800]];
      case MemberRole.member:
        return [Colors.blue[100], Colors.blue[800]];
    }
  }

  String _getMemberRoleLabel(MemberRole role) {
    switch (role) {
      case MemberRole.founder:
        return 'Founder';
      case MemberRole.administrator:
        return 'Admin';
      case MemberRole.member:
        return 'Member';
    }
  }

  void _showEditGroupDialog() {
    if (_group == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditGroupPage(groupId: _group!.groupId),
      ),
    ).then((value) {
      if (value == true) {
        _loadGroup(); // Reload group details if changes were saved
      }
    });
  }

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Member'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search Users',
                    labelStyle:
                        TextStyle(color: Color.fromARGB(255, 51, 75, 71)),
                    border: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: Color.fromARGB(255, 51, 75, 71)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: Color.fromARGB(255, 51, 75, 71)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: Color.fromARGB(255, 51, 75, 71)),
                    ),
                    prefixIcon: Icon(Icons.search,
                        color: Color.fromARGB(255, 51, 75, 71)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (query) async {
                    if (query.isEmpty) {
                      setState(() => _searchedUsers = []);
                      return;
                    }

                    try {
                      final response = await _apiService.get('/users/search');

                      if (response.statusCode == 200) {
                        final List<dynamic> usersJson =
                            jsonDecode(response.body);
                        final List<UserAccount> allUsers = usersJson
                            .map((json) => UserAccount(
                                  userId: json['userId'],
                                  userName: json['username'],
                                  firstName: json['firstName'],
                                  lastName: json['lastName'],
                                  email: json['email'],
                                  passwordHash: '',
                                  createdAt: DateTime.parse(json['createdAt']),
                                  updatedAt: DateTime.parse(json['updatedAt']),
                                ))
                            .toList();

                        setState(() {
                          _searchedUsers = allUsers
                              .where((user) =>
                                  user.userName
                                      .toLowerCase()
                                      .contains(query.toLowerCase()) ||
                                  user.firstName
                                      .toLowerCase()
                                      .contains(query.toLowerCase()) ||
                                  user.lastName
                                      .toLowerCase()
                                      .contains(query.toLowerCase()))
                              .toList();
                        });
                      }
                    } catch (e) {
                      // ne need to catch error
                    }
                  },
                ),
                if (_searchedUsers.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color.fromARGB(255, 51, 75, 71)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchedUsers.length,
                      itemBuilder: (context, index) {
                        final user = _searchedUsers[index];
                        return ListTile(
                          title: Text(user.userName),
                          subtitle: Text('${user.firstName} ${user.lastName}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle,
                                color: Colors.green),
                            onPressed: () {
                              Navigator.pop(context);
                              _handleAddMember(user.userId.toString());
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAddMember(String userId) async {
    try {
      await _groupController.addMemberToGroup(
        int.parse(widget.groupId),
        int.parse(userId),
        MemberRole.member,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member added successfully')),
        );
        _loadGroup(); // Reload group details
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding member: $e')),
        );
      }
    }
  }

  void _showDeleteGroupConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text(
            'Are you sure you want to delete this group? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteGroup();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroup() async {
    if (_group == null) return;

    try {
      await _groupController.deleteGroup(_group!.groupId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group deleted successfully')),
        );
        Navigator.pop(context); // Go back to groups list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting group: $e')),
        );
      }
    }
  }

  void _showRemoveMemberConfirmation(GroupMember member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
            'Are you sure you want to remove ${member.firstName} ${member.lastName} from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _removeMember(member);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(GroupMember member) async {
    if (_group == null) return;

    setState(() => _isLoading = true);

    try {
      await _groupController.removeMemberFromGroup(
          _group!.groupId, member.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${member.firstName} ${member.lastName} has been removed from the group')),
        );
        _loadGroup(); // Reload group details
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing member: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
