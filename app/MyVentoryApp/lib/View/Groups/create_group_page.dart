import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_ventory_mobile/Model/group.dart';
import 'package:my_ventory_mobile/Controller/group_controller.dart';
import 'dart:io';
import 'package:my_ventory_mobile/Model/page_template.dart';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart';
import 'package:my_ventory_mobile/Model/user.dart';
import 'dart:convert';

class CreateGroupPage extends PageTemplate {
  final int userId;

  const CreateGroupPage({
    super.key,
    required this.userId,
  });

  @override
  PageTemplateState<CreateGroupPage> createState() => CreateGroupPageState();
}

class CreateGroupPageState extends PageTemplateState<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final GroupController _groupController = GroupController();
  final _apiService = ApiService();
  GroupPrivacy _privacy = GroupPrivacy.public;
  List<UserAccount> _searchedUsers = [];
  final List<UserAccount> _selectedMembers = [];
  // Keeping this for future implementation
  // ignore: unused_field
  final String _searchQuery = '';
  // Keeping this for future implementation
  // ignore: unused_field
  File? _groupProfilePicture;
  bool _isLoading = false;

  // Keeping this for future implementation
  // ignore: unused_element
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _groupProfilePicture = File(pickedFile.path);
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchedUsers = [];
      });
      return;
    }

    try {
      final response = await _apiService.get('/users/search');

      if (response.statusCode == 200) {
        final List<dynamic> usersJson = jsonDecode(response.body);
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
                  user.userName.toLowerCase().contains(query.toLowerCase()) ||
                  user.firstName.toLowerCase().contains(query.toLowerCase()) ||
                  user.lastName.toLowerCase().contains(query.toLowerCase()))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error searching users: $e');
    }
  }

  void _addMember(UserAccount user) {
    setState(() {
      if (!_selectedMembers.contains(user)) {
        _selectedMembers.add(user);
      }
    });
  }

  void _removeMember(UserAccount user) {
    setState(() {
      _selectedMembers.remove(user);
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() {
          _isLoading = true;
        });

        // Create the group
        final Group createdGroup = await _groupController.createGroup(
          name: _nameController.text,
          privacy: _privacy,
          description: _descriptionController.text,
        );

        // Add selected members to the group
        if (_selectedMembers.isNotEmpty) {
          for (final member in _selectedMembers) {
            try {
              await _groupController.addMemberToGroup(
                createdGroup.groupId,
                member.userId,
                MemberRole.member,
              );
            } catch (memberError) {
              debugPrint(
                  'Error adding member ${member.userName}: $memberError');
              // Continue with other members even if one fails
            }
          }
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Group created successfully with members')),
        );
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating group: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget pageBody(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color.fromARGB(255, 131, 184, 175),
          appBar: AppBar(
            backgroundColor: const Color.fromARGB(255, 87, 143, 134),
            title: const Text('Create Group',
                style: TextStyle(color: Colors.white)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Group Information Card
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Group Information',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Group Name',
                                labelStyle: TextStyle(
                                    color: Color.fromARGB(255, 51, 75, 71)),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Color.fromARGB(255, 51, 75, 71)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Color.fromARGB(255, 51, 75, 71)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Color.fromARGB(255, 51, 75, 71)),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a group name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descriptionController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                labelStyle: TextStyle(
                                    color: Color.fromARGB(255, 51, 75, 71)),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Color.fromARGB(255, 51, 75, 71)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Color.fromARGB(255, 51, 75, 71)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Color.fromARGB(255, 51, 75, 71)),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Privacy',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                Radio<GroupPrivacy>(
                                  value: GroupPrivacy.public,
                                  groupValue: _privacy,
                                  onChanged: (GroupPrivacy? value) {
                                    setState(() {
                                      _privacy = value!;
                                    });
                                  },
                                ),
                                const Text('Public'),
                                const SizedBox(width: 16),
                                Radio<GroupPrivacy>(
                                  value: GroupPrivacy.private,
                                  groupValue: _privacy,
                                  onChanged: (GroupPrivacy? value) {
                                    setState(() {
                                      _privacy = value!;
                                    });
                                  },
                                ),
                                const Text('Private'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Members Card
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add Members',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'Search Users',
                                labelStyle: TextStyle(
                                    color: Color.fromARGB(255, 51, 75, 71)),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Color.fromARGB(255, 51, 75, 71)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Color.fromARGB(255, 51, 75, 71)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Color.fromARGB(255, 51, 75, 71)),
                                ),
                                prefixIcon: Icon(Icons.search,
                                    color: Color.fromARGB(255, 51, 75, 71)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              onChanged: _searchUsers,
                            ),
                            if (_searchedUsers.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: const Color.fromARGB(
                                          255, 51, 75, 71)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _searchedUsers.length,
                                  itemBuilder: (context, index) {
                                    final user = _searchedUsers[index];
                                    final isSelected =
                                        _selectedMembers.contains(user);
                                    return ListTile(
                                      title: Text(user.userName),
                                      subtitle: Text(
                                          '${user.firstName} ${user.lastName}'),
                                      trailing: IconButton(
                                        icon: Icon(
                                          isSelected
                                              ? Icons.remove_circle
                                              : Icons.add_circle,
                                          color: isSelected
                                              ? Colors.red
                                              : Colors.green,
                                        ),
                                        onPressed: () {
                                          if (isSelected) {
                                            _removeMember(user);
                                          } else {
                                            _addMember(user);
                                          }
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                            if (_selectedMembers.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Selected Members',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: const Color.fromARGB(
                                          255, 51, 75, 71)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _selectedMembers.length,
                                  itemBuilder: (context, index) {
                                    final user = _selectedMembers[index];
                                    return ListTile(
                                      title: Text(user.userName),
                                      subtitle: Text(
                                          '${user.firstName} ${user.lastName}'),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.remove_circle,
                                            color: Colors.red),
                                        onPressed: () => _removeMember(user),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Submit Button
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 87, 143, 134),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Create Group',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withAlpha(100),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}
