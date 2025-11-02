import 'package:flutter/material.dart';
import '../servers/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  String email = '', password = '';
  bool isLoading = false;

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final user = await _authService.signIn(email, password);

    setState(() => isLoading = false);

    if (user != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('✅ مرحبًا ${user.username}!')));

      // الانتقال بناءً على نوع المستخدم
      if (user.role == 'guide') {
        Navigator.pushReplacementNamed(context, '/createRoad');
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('❌ فشل تسجيل الدخول')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                ),
                onChanged: (val) => email = val,
                validator: (val) =>
                    val!.isEmpty ? 'أدخل البريد الإلكتروني' : null,
              ),
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة المرور'),
                onChanged: (val) => password = val,
                validator: (val) => val!.isEmpty ? 'أدخل كلمة المرور' : null,
              ),
              const SizedBox(height: 20),
              isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      child: const Text('تسجيل الدخول'),
                    ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: const Text('إنشاء حساب جديد'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
