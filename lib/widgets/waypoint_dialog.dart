import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/waypoint.dart';

/// Dialog for adding a waypoint with quiz to a recorded route
class WaypointDialog extends StatefulWidget {
  final List<LatLng> recordedPoints;
  final Function(Waypoint) onAdd;

  const WaypointDialog({
    super.key,
    required this.recordedPoints,
    required this.onAdd,
  });

  @override
  State<WaypointDialog> createState() => _WaypointDialogState();
}

class _WaypointDialogState extends State<WaypointDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  int _correctIndex = 0;
  int _selectedPointIndex = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleAdd() {
    // Validate inputs
    if (_nameController.text.isEmpty || _questionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in name and question'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final options = _optionControllers.map((c) => c.text).toList();
    if (options.any((o) => o.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all options'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Create waypoint
    final point = widget.recordedPoints[_selectedPointIndex];
    final waypoint = Waypoint(
      name: _nameController.text,
      location: point,
      question: _questionController.text,
      options: options,
      correctIndex: _correctIndex,
    );

    widget.onAdd(waypoint);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add Waypoint'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Point selector
            const Text(
              'Select point on route:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedPointIndex,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _buildPointDropdownItems(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedPointIndex = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Waypoint name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Waypoint Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Quiz question
            TextField(
              controller: _questionController,
              decoration: const InputDecoration(
                labelText: 'Quiz Question',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // Options
            const Text(
              'Options:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...List.generate(4, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Radio<int>(
                      value: index,
                      groupValue: _correctIndex,
                      onChanged: (value) {
                        setState(() => _correctIndex = value!);
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _optionControllers[index],
                        decoration: InputDecoration(
                          labelText: 'Option ${index + 1}',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _handleAdd,
          child: const Text('Add'),
        ),
      ],
    );
  }

  /// Build dropdown items for point selection
  /// Shows every 10th point to avoid overwhelming the user
  List<DropdownMenuItem<int>> _buildPointDropdownItems() {
    return List.generate(
      (widget.recordedPoints.length / 10).ceil(),
      (index) {
        final pointIndex = index * 10;
        if (pointIndex < widget.recordedPoints.length) {
          final point = widget.recordedPoints[pointIndex];
          return DropdownMenuItem(
            value: pointIndex,
            child: Text(
              'Point ${pointIndex + 1}: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
            ),
          );
        }
        return null;
      },
    ).whereType<DropdownMenuItem<int>>().toList();
  }
}
