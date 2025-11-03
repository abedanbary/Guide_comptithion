import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditRoadScreen extends StatefulWidget {
  final String roadId;
  final Map<String, dynamic> roadData;

  const EditRoadScreen({
    super.key,
    required this.roadId,
    required this.roadData,
  });

  @override
  State<EditRoadScreen> createState() => _EditRoadScreenState();
}

class _EditRoadScreenState extends State<EditRoadScreen> {
  late TextEditingController _roadNameController;
  late List<Map<String, dynamic>> _points;
  bool _isSaving = false;

  // Professional color palette
  static const Color primaryBlue = Color(0xFF3D5A80);
  static const Color accentGold = Color(0xFFE9C46A);
  static const Color darkBlue = Color(0xFF2A3F5F);
  static const Color backgroundColor = Color(0xFFF5F7FA);
  static const Color cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _roadNameController = TextEditingController(
      text: widget.roadData['roadName'] ?? '',
    );
    _points = List<Map<String, dynamic>>.from(
      (widget.roadData['points'] as List?)?.map((p) => Map<String, dynamic>.from(p)) ?? [],
    );
  }

  Future<void> _saveChanges() async {
    if (_roadNameController.text.isEmpty) {
      _showSnackBar('Please enter a route name', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('roads')
          .doc(widget.roadId)
          .update({
        'roadName': _roadNameController.text,
        'points': _points,
      });

      if (mounted) {
        _showSnackBar('Route updated successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _editPoint(int index) {
    final point = _points[index];
    final nameController = TextEditingController(text: point['name'] ?? '');
    final questionController = TextEditingController(text: point['question'] ?? '');
    final option1Controller = TextEditingController(
      text: (point['options'] as List?)?.elementAtOrNull(0) ?? '',
    );
    final option2Controller = TextEditingController(
      text: (point['options'] as List?)?.elementAtOrNull(1) ?? '',
    );
    final option3Controller = TextEditingController(
      text: (point['options'] as List?)?.elementAtOrNull(2) ?? '',
    );
    final option4Controller = TextEditingController(
      text: (point['options'] as List?)?.elementAtOrNull(3) ?? '',
    );
    int correctIndex = point['correctIndex'] ?? 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_location, color: primaryBlue),
              ),
              const SizedBox(width: 12),
              Text('Edit Waypoint ${index + 1}'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Waypoint Name',
                    prefixIcon: const Icon(Icons.place, color: primaryBlue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: questionController,
                  decoration: InputDecoration(
                    labelText: 'Question',
                    prefixIcon: const Icon(Icons.quiz, color: primaryBlue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Answer Options',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...[
                  option1Controller,
                  option2Controller,
                  option3Controller,
                  option4Controller,
                ].asMap().entries.map((entry) {
                  final i = entry.key;
                  final controller = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'Option ${String.fromCharCode(65 + i)}',
                        prefixIcon: Radio<int>(
                          value: i,
                          groupValue: correctIndex,
                          onChanged: (val) {
                            setDialogState(() => correctIndex = val!);
                          },
                          activeColor: primaryBlue,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  );
                }).toList(),
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
                setState(() {
                  _points[index] = {
                    ..._points[index],
                    'name': nameController.text,
                    'question': questionController.text,
                    'options': [
                      option1Controller.text,
                      option2Controller.text,
                      option3Controller.text,
                      option4Controller.text,
                    ],
                    'correctIndex': correctIndex,
                  };
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Edit Route',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryBlue,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              onPressed: _saveChanges,
              icon: const Icon(Icons.check),
              tooltip: 'Save Changes',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route Name Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.route, color: primaryBlue),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Route Name',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: darkBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _roadNameController,
                    decoration: InputDecoration(
                      hintText: 'Enter route name...',
                      prefixIcon: const Icon(Icons.hiking_rounded, color: primaryBlue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Waypoints Section
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_on, color: primaryBlue),
                ),
                const SizedBox(width: 12),
                Text(
                  'Waypoints (${_points.length})',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (_points.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No waypoints',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...List.generate(_points.length, (index) {
                final point = _points[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: primaryBlue,
                      radius: 24,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    title: Text(
                      point['name'] ?? 'Waypoint ${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          point['question'] ?? 'No question',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.quiz,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(point['options'] as List?)?.length ?? 0} options',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      onPressed: () => _editPoint(index),
                      icon: const Icon(Icons.edit),
                      color: accentGold,
                      tooltip: 'Edit',
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _roadNameController.dispose();
    super.dispose();
  }
}
