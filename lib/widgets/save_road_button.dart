import 'package:flutter/material.dart';

class SaveRoadButton extends StatelessWidget {
  final VoidCallback onPressed;
  const SaveRoadButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.save),
      label: const Text('Save Road'),
    );
  }
}
