import 'dart:io';

import 'package:glass_forge_workbench/exports.dart';

class CustomImagePicker extends StatelessWidget {
  const CustomImagePicker({
    required this.onButtonPressed,
    required this.imagePath,
    super.key,
  });

  final VoidCallback onButtonPressed;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onButtonPressed,
      icon: imagePath == null || (imagePath ?? '').isEmpty
          ? const Icon(Icons.add_a_photo)
          : ClipOval(child: _getImageWidget(imagePath!)),
      padding: EdgeInsetsDirectional.all(
        imagePath == null || (imagePath ?? '').isEmpty ? 50 : 0,
      ),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        side: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  Widget _getImageWidget(String imagePath) {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        height: 130.03,
        width: 130.03,
        imagePath,
        fit: BoxFit.cover,
      );
    } else {
      return Image.file(
        height: 130.03,
        width: 130.03,
        fit: BoxFit.cover,
        File(imagePath.replaceFirst('file://', '')),
      );
    }
  }
}
