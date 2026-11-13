import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'home_dashboard.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  bool isLoginMode = false;
  bool isPasswordVisible = false;
  bool isLoading = false;
  bool agreedToRules = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'यह Gmail पहले से रजिस्टर्ड है! कृपया Login करें।';
      case 'invalid-email':
        return 'Gmail एड्रेस सही नहीं है।';
      case 'weak-password':
        return 'पासवर्ड कम से कम 6 अक्षर का मजबूत रखें।';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Gmail या Password गलत है!';
      case 'network-request-failed':
        return 'इंटरनेट कनेक्शन चेक करें।';
      default:
        return e.message ?? 'Authentication एरर आया है।';
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (!isLoginMode && !agreedToRules) {
      _showMessage('कृपया 1 Phone = 1 Account नियम स्वीकार करें।', isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      if (isLoginMode) {
        await FirebaseService.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await FirebaseService.signUp(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          referralCode: _referralController.text,
        );
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeDashboard()),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showMessage(_friendlyAuthError(e), isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showMessage('दिक्कत आई: $e', isError: true);
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      _showMessage('पहले ऊपर अपना Gmail लिखें, फिर Forgot Password दबाएं।',
          isError: true);
      return;
    }
    try {
      await FirebaseService.sendPasswordReset(email);
      if (!mounted) return;
      _showMessage('Password Reset लिंक आपके Gmail पर भेज दिया गया है!');
    } catch (e) {
      _showMessage('ईमेल भेजने में दिक्कत आई: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'TaskEarn & Beta Tester',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Live Cloud Account • ऐप्स टेस्ट करें और कमाएं!',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => isLoginMode = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: !isLoginMode
                                          ? const Color(0xFF4F46E5)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Sign Up (नया खाता)',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: !isLoginMode
                                            ? Colors.white
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => isLoginMode = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isLoginMode
                                          ? const Color(0xFF4F46E5)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Login (लॉगिन)',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isLoginMode
                                            ? Colors.white
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (!isLoginMode) ...[
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'आपका पूरा नाम',
                              hintText: 'उदाहरण: राहुल शर्मा',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().length < 2) {
                                return 'कृपया अपना सही नाम लिखें';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Play Store Gmail ID',
                            hintText: 'उदाहरण: yourname@gmail.com',
                            helperText: 'टेस्टिंग लिंक के लिए असली Gmail ही डालें',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            if (value == null ||
                                !value.contains('@') ||
                                !value.contains('.')) {
                              return 'सही Gmail एड्रेस डालें';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !isPasswordVisible,
                          decoration: InputDecoration(
                            labelText: 'पासवर्ड (Password)',
                            hintText: 'कम से कम 6 अक्षर',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  isPasswordVisible = !isPasswordVisible;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().length < 6) {
                              return 'पासवर्ड कम से कम 6 अक्षर का होना चाहिए';
                            }
                            return null;
                          },
                        ),
                        if (isLoginMode)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _forgotPassword,
                              child: const Text('Password भूल गए?'),
                            ),
                          ),
                        if (!isLoginMode) ...[
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _referralController,
                            decoration: const InputDecoration(
                              labelText: 'Referral Code (वैकल्पिक)',
                              hintText: 'उदाहरण: TASK1234 (+25 एक्स्ट्रा कॉइन)',
                              prefixIcon: Icon(Icons.card_giftcard_outlined),
                            ),
                          ),
                          const SizedBox(height: 10),
                          CheckboxListTile(
                            value: agreedToRules,
                            onChanged: (val) =>
                                setState(() => agreedToRules = val ?? false),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text(
                              'मैं 1 Phone = 1 Account और 14-दिन टेस्टिंग नियमों से सहमत हूं।',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : Text(
                                    isLoginMode
                                        ? 'Login करें'
                                        : 'Sign Up करें (+50 Coins)',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
