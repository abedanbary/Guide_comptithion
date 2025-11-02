import 'package:flutter/material.dart';

class RoadNameInput extends StatelessWidget {
  final TextEditingController controller;
  const RoadNameInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Road Name',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}
