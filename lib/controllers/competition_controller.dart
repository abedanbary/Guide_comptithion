import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:guide_comptiton/models/Competition.dart';

class CompetitionController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ✅ إنشاء مسابقة جديدة
  Future<void> createCompetition({
    required String title,
    required String roadId,
    required String roadName,
  }) async {
    final competitionId = DateTime.now().millisecondsSinceEpoch.toString();

    final data = {
      'competitionId': competitionId,
      'title': title,
      'roadId': roadId,
      'roadName': roadName,
      'createdAt': DateTime.now(),
      'createdBy': _auth.currentUser?.email ?? 'Unknown',
      'competitors': [],
      'scores': [],
      'isPublished': true,
    };

    await _firestore.collection('competitions').doc(competitionId).set(data);
  }

  /// ✅ جلب جميع المسابقات
  Stream<QuerySnapshot> getCompetitionsStream() {
    return _firestore
        .collection('competitions')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// ✅ حذف مسابقة
  Future<void> deleteCompetition(String id) async {
    await _firestore.collection('competitions').doc(id).delete();
  }

  Stream<QuerySnapshot> getMyCompetitionsStream(String userId) {
    return _firestore
        .collection('competitions')
        .where('createdBy', isEqualTo: userId) // فلترة حسب المستخدم
        .orderBy('createdAt', descending: true) // ترتيب حسب وقت الإنشاء
        .snapshots();
  }

  Future<void> editCompetition(Competition comp) async {
    try {
      await _firestore
          .collection('competitions')
          .doc(comp.id.toString())
          .update(comp.toJson());

      print('✅ تم تعديل المسابقة بنجاح');
    } catch (e) {
      print('❌ فشل تعديل المسابقة: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllCompetitorsWithScores(
    String competitionId,
  ) async {
    try {
      final doc = await _firestore
          .collection('competitions')
          .doc(competitionId)
          .get();

      if (!doc.exists) {
        print('❌ لم يتم العثور على المسابقة');
        return [];
      }

      final data = doc.data()!;
      final List competitors = data['competitors'] ?? [];
      final List scores = data['scores'] ?? [];

      // دمج المتسابقين مع درجاتهم في قائمة واحدة
      final List<Map<String, dynamic>> results = [];
      for (int i = 0; i < competitors.length; i++) {
        results.add({
          'name': competitors[i],
          'score': i < scores.length
              ? scores[i]
              : 0, // إذا لا توجد درجة نحطها 0
        });
      }

      return results;
    } catch (e) {
      print('❌ خطأ أثناء جلب المتسابقين: $e');
      return [];
    }
  }
}
