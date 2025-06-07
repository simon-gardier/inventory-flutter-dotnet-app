import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PicturePage {
  static final ImagePicker picker = ImagePicker();

  // ==========================================================================
  // Ask the user if they want to pick a picture from gallery of take it with camera
  static Future<List<String>> showImageSourceDialog(
      BuildContext context) async {
    List<String> returnedPaths = [];

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take Photo'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
    if (context.mounted) {
      if (source == ImageSource.gallery) {
        returnedPaths = await pickImageFromGallery(context);
      } else if (source == ImageSource.camera) {
        returnedPaths = await takePictureWithCamera(context);
      }
    }
    return returnedPaths;
  }

  // ==========================================================================

  // ==========================================================================
  // Picks image(s) from Gallery
  static Future<List<String>> pickImageFromGallery(BuildContext context) async {
    final ImagePicker picker = ImagePicker();

    try {
      final List<XFile> pickedFiles = await picker.pickMultiImage();

      if (pickedFiles.isNotEmpty) {
        return pickedFiles.map((file) => file.path).toList();
      } else {
        return [];
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
      return [];
    }
  }
  // ==========================================================================

  // ==========================================================================
  //Takes Picture with Camera
  static Future<List<String>> takePictureWithCamera(
      BuildContext context) async {
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.camera,
      );

      if (pickedFile != null) {
        return [pickedFile.path];
      } else {
        return [];
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking picture: $e')),
        );
      }
      return [];
    }
  }
  // ==========================================================================
}
