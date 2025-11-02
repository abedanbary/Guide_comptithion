import 'package:cloud_firestore/cloud_firestore.dart';

class RoadController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ إضافة طريق جديد
  Future<void> addRoad(Map<String, dynamic> roadData) async {
    await _firestore.collection('roads').add(roadData);
  }

  /// ✅ جلب جميع الطرق
  Stream<QuerySnapshot> getRoadsStream() {
    return _firestore
        .collection('roads')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// ✅ حذف طريق
  Future<void> deleteRoad(String id) async {
    await _firestore.collection('roads').doc(id).delete();
  }
}
