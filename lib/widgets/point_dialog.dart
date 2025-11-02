import 'package:flutter/material.dart';

class PointDialog extends StatefulWidget {
  const PointDialog({super.key});

  @override
  State<PointDialog> createState() => _PointDialogState();
}

class _PointDialogState extends State<PointDialog> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController questionController = TextEditingController();
  final List<TextEditingController> optionControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  int correctAnswerIndex = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Point & Quiz'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Point Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: questionController,
              decoration: const InputDecoration(labelText: 'Quiz Question'),
            ),
            const SizedBox(height: 10),
            const Text('Options:'),
            for (int i = 0; i < 4; i++)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: optionControllers[i],
                      decoration: InputDecoration(labelText: 'Option ${i + 1}'),
                    ),
                  ),
                  Radio<int>(
                    value: i,
                    groupValue: correctAnswerIndex,
                    onChanged: (val) => setState(() {
                      correctAnswerIndex = val!;
                    }),
                  ),
                  const Text('Correct'),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (nameController.text.isEmpty ||
                questionController.text.isEmpty ||
                optionControllers.any((c) => c.text.isEmpty)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please fill all fields')),
              );
              return;
            }

            Navigator.pop(context, {
              'name': nameController.text,
              'question': questionController.text,
              'options': optionControllers.map((c) => c.text).toList(),
              'correctIndex': correctAnswerIndex,
            });
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
