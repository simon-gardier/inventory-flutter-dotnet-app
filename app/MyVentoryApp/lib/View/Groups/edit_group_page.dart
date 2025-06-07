import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_ventory_mobile/Model/group.dart';
import 'package:my_ventory_mobile/Controller/group_controller.dart';
import 'package:my_ventory_mobile/Model/page_template.dart';
import 'package:my_ventory_mobile/Model/text_boxes.dart';

class EditGroupPage extends PageTemplate {
  final int groupId;

  const EditGroupPage({
    super.key,
    required this.groupId,
  });

  @override
  PageTemplateState<EditGroupPage> createState() => EditGroupPageState();
}

class EditGroupPageState extends PageTemplateState<EditGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final GroupController _groupController = GroupController();
  GroupPrivacy _privacy = GroupPrivacy.public;
  File? _groupProfilePicture;
  Uint8List? _imageBytes;
  String? _currentProfilePicture;
  bool _isLoading = false;
  Group? _group;

  @override
  void initState() {
    super.initState();
    _loadGroupData();
  }

  Future<void> _loadGroupData() async {
    setState(() => _isLoading = true);
    try {
      _group = await _groupController.getGroupById(widget.groupId);
      if (_group != null) {
        setState(() {
          _nameController.text = _group!.name;
          _descriptionController.text = _group!.description;
          _privacy = _group!.privacy;
          _currentProfilePicture = _group!.groupProfilePicture != null
              ? base64Encode(_group!.groupProfilePicture!)
              : null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading group: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _groupProfilePicture = File(pickedFile.path);
        _imageBytes = bytes;
        _currentProfilePicture = null; // Clear current profile picture
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _groupController.updateGroup(
        groupId: widget.groupId,
        name: _nameController.text,
        privacy: _privacy,
        description: _descriptionController.text,
        groupProfilePicture: _groupProfilePicture,
        imageBytes: _imageBytes,
        imageName: _groupProfilePicture?.path.split('/').last,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group updated successfully')),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating group: $e')),
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
    if (_isLoading && _group == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final fieldWidth = screenWidth * 0.9; // Consistent width for all fields

    // Determine which image to display
    Widget profileImageWidget;

    if (_imageBytes != null) {
      // For selected image
      profileImageWidget = CircleAvatar(
        radius: 50,
        backgroundImage: MemoryImage(_imageBytes!),
      );
    } else if (_currentProfilePicture != null) {
      // For existing profile picture from the server
      try {
        profileImageWidget = CircleAvatar(
          radius: 50,
          backgroundImage: MemoryImage(base64Decode(_currentProfilePicture!)),
        );
      } catch (e) {
        // Fallback for decoding errors
        profileImageWidget = const CircleAvatar(
          radius: 50,
          backgroundImage: AssetImage('assets/default_profile.jpg'),
        );
      }
    } else {
      // Default profile picture
      profileImageWidget = const CircleAvatar(
        radius: 50,
        backgroundImage: AssetImage('assets/default_profile.jpg'),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      profileImageWidget,
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 87, 143, 134),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: fieldWidth,
                child: TextBox(
                  backText: "Group Name",
                  boxC: _nameController,
                  boxWidth: fieldWidth,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: fieldWidth,
                child: TextBox(
                  backText: "Description",
                  boxC: _descriptionController,
                  boxWidth: fieldWidth,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: fieldWidth,
                child: DropdownButtonFormField<GroupPrivacy>(
                  value: _privacy,
                  decoration: InputDecoration(
                    labelText: 'Privacy',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: GroupPrivacy.values.map((privacy) {
                    return DropdownMenuItem(
                      value: privacy,
                      child: Text(privacy == GroupPrivacy.public
                          ? 'Public'
                          : 'Private'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _privacy = value;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: fieldWidth,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 87, 143, 134),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _saveChanges,
                          child: const Text("Save Changes"),
                        ),
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
