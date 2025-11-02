import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CompetitionScreen extends StatefulWidget {
  const CompetitionScreen({super.key});

  @override
  State<CompetitionScreen> createState() => _CompetitionScreenState();
}

class _CompetitionScreenState extends State<CompetitionScreen> {
  String? _selectedRoadId;
  String? _selectedRoadName;
  final TextEditingController _titleController = TextEditingController();
  bool _isPublished = false;

  /// تحميل الطرق من Firestore
  Stream<QuerySnapshot> _loadRoads() {
    return FirebaseFirestore.instance.collection('roads').snapshots();
  }

  /// نشر المسابقة
  Future<void> _publishCompetition() async {
    if (_selectedRoadId == null || _titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال عنوان المسابقة واختيار الطريق'),
        ),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final competitionId = DateTime.now().millisecondsSinceEpoch.toString();

    final competitionData = {
      'competitionId': competitionId,
      'title': _titleController.text,
      'createdBy': currentUser?.email ?? 'Unknown',
      'createdAt': DateTime.now(),
      'roadId': _selectedRoadId,
      'roadName': _selectedRoadName,
      'competitors': [],
      'scores': [],
      'isPublished': true,
    };

    await FirebaseFirestore.instance
        .collection('competitions')
        .doc(competitionId)
        .set(competitionData);

    setState(() => _isPublished = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ تم إنشاء المسابقة ونشرها بنجاح!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء مسابقة 🏁'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎯 عنوان المسابقة:', style: TextStyle(fontSize: 18)),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'اكتب عنوان المسابقة هنا...',
              ),
            ),
            const SizedBox(height: 20),
            const Text('🗺️ اختر الطريق:', style: TextStyle(fontSize: 18)),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _loadRoads(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('🚫 لا توجد طرق محفوظة.'));
                  }

                  final roads = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: roads.length,
                    itemBuilder: (context, index) {
                      final road = roads[index];
                      final selected = _selectedRoadId == road.id;

                      return Card(
                        child: ListTile(
                          title: Text(road['roadName']),
                          subtitle: Text(
                            "عدد النقاط: ${(road['points'] as List).length}",
                          ),
                          trailing: selected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedRoadId = road.id;
                              _selectedRoadName = road['roadName'];
                            });
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isPublished ? null : _publishCompetition,
                icon: const Icon(Icons.flag),
                label: Text(_isPublished ? '🏆 تم النشر' : 'نشر المسابقة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPublished
                      ? Colors.grey
                      : Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
