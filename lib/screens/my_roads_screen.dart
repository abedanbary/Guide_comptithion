import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyRoadsScreen extends StatelessWidget {
  const MyRoadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Roads 🛣️'),
        backgroundColor: Colors.green.shade700,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('roads')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                '😕 لا توجد طرق محفوظة بعد',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          final roads = snapshot.data!.docs;

          return ListView.builder(
            itemCount: roads.length,
            itemBuilder: (context, index) {
              final road = roads[index];
              final data = road.data() as Map<String, dynamic>;

              final name = data['roadName'] ?? 'بدون اسم';
              final createdAt = data['createdAt']?.toDate()?.toString().split(
                '.',
              )[0];
              final pointsCount = (data['points'] as List?)?.length ?? 0;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '📍 عدد النقاط: $pointsCount\n🕒 تاريخ الحفظ: $createdAt',
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(name),
                        content: Text(
                          'عدد النقاط: $pointsCount\n\nيمكن لاحقًا عرض هذه الطريق على الخريطة.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('إغلاق'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
