import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<AppUser?> signUp({
    required String email,
    required String password,
    required String username,
    required String role, // "guide" or "student"
  }) async {
    try {
      print('🔄 محاولة إنشاء حساب...');
      print('📧 Email: $email');
      print('👤 Username: $username');
      print('👔 Role: $role');

      // Create user in Firebase Auth
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      print('✅ تم إنشاء المستخدم في Firebase Auth');
      print('🆔 UID: ${userCredential.user!.uid}');

      final user = AppUser(
        uid: userCredential.user!.uid,
        email: email,
        username: username,
        role: role,
      );

      print('🔄 حفظ البيانات في Firestore...');

      // Save user data to Firestore
      await _firestore.collection('users').doc(user.uid).set(user.toJson());

      print('✅ تم حفظ البيانات بنجاح في Firestore');

      return user;
    } on FirebaseAuthException catch (e) {
      print("❌ Firebase Auth Error Code: ${e.code}");
      print("❌ Firebase Auth Error Message: ${e.message}");

      // رسائل خطأ مفصلة بالعربية
      String errorMessage = _getArabicErrorMessage(e.code);
      print("❌ الخطأ بالعربية: $errorMessage");

      return null;
    } on FirebaseException catch (e) {
      print("❌ Firestore Error: ${e.message}");
      return null;
    } catch (e) {
      print("❌ خطأ غير متوقع: $e");
      return null;
    }
  }

  Future<AppUser?> signIn(String email, String password) async {
    try {
      print('🔄 محاولة تسجيل الدخول...');

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ تم تسجيل الدخول في Firebase Auth');
      print('🆔 UID: ${userCredential.user!.uid}');

      // Fetch user data from Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        print('❌ المستخدم غير موجود في Firestore');
        return null;
      }

      print('✅ تم جلب بيانات المستخدم من Firestore');

      return AppUser.fromJson(userDoc.data() as Map<String, dynamic>);
    } on FirebaseAuthException catch (e) {
      print("❌ Firebase Auth Error: ${e.code} - ${e.message}");
      return null;
    } catch (e) {
      print("❌ Sign in error: $e");
      return null;
    }
  }

  // دالة لترجمة أخطاء Firebase للعربية
  String _getArabicErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً';
      case 'email-already-in-use':
        return 'البريد الإلكتروني مستخدم بالفعل';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صحيح';
      case 'operation-not-allowed':
        return 'العملية غير مسموحة';
      case 'user-disabled':
        return 'الحساب معطل';
      case 'user-not-found':
        return 'المستخدم غير موجود';
      case 'wrong-password':
        return 'كلمة المرور خاطئة';
      case 'network-request-failed':
        return 'فشل الاتصال بالإنترنت';
      case 'too-many-requests':
        return 'محاولات كثيرة جداً، حاول لاحقاً';
      default:
        return 'حدث خطأ: $errorCode';
    }
  }

  // دالة للحصول على المستخدم الحالي
  User? get currentUser => _auth.currentUser;

  // دالة لتسجيل الخروج
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
