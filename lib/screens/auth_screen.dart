import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  // true = Login फॉर्म दिखेगा, false = Sign Up फॉर्म दिखेगा
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

  // यूज़र के लिए यूनीक Referral Code बनाने का लॉजिक (उदाहरण: TASK4821)
  String _generateReferralCode() {
    final random = Random();
    final number = 1000 + random.nextInt(9000);
    return 'TASK$number';
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (!isLoginMode && !agreedToRules) {
      _showMessage('कृपया नियम (1 Device = 1 Account) स्वीकार करें।', isError: true);
      return;
    }

    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    if (isLoginMode) {
      // --- LOGIN LOGIC ---
      final savedEmail = prefs.getString('user_email');
      final savedPassword = prefs.getString('user_password');

      if (savedEmail == null) {
        setState(() => isLoading = false);
        _showMessage('कोई अकाउंट नहीं मिला! पहले Sign Up करें।', isError: true);
        return;
      }

      if (email == savedEmail && password == savedPassword) {
        await prefs.setBool('is_logged_in', true);
        if (!mounted) return;
        _goToHome();
      } else {
        setState(() => isLoading = false);
        _showMessage('Gmail या Password गलत है!', isError: true);
      }
    } else {
      // --- SIGN UP LOGIC ---
      final name = _nameController.text.trim();
      final appliedReferral = _referralController.text.trim().toUpperCase();

      // अगर यूज़र ने रेफरल कोड डाला है तो एक्स्ट्रा 25 कॉइन, वरना 50 वेलकम कॉइन
      int welcomeCoins = 50;
      if (appliedReferral.isNotEmpty) {
        welcomeCoins += 25;
      }

      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_name', name);
      await prefs.setString('user_email', email);
      await prefs.setString('user_password', password);
      await prefs.setInt('user_coins', welcomeCoins);
      await prefs.setString('my_referral_code', _generateReferralCode());

      if (!mounted) return;
      _showMessage('अकाउंट बन गया! आपको $welcomeCoins Welcome Coins मिले हैं।');
      _goToHome();
    }
  }

  // जल्दी टेस्ट करने के लिए 1-क्लिक Demo Account
  Future<void> _demoLogin() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('user_name', 'Demo Tester');
    await prefs.setString('user_email', 'demotester@gmail.com');
    await prefs.setString('user_password', '123456');
    await prefs.setInt('user_coins', prefs.getInt('user_coins') ?? 100);
    await prefs.setString(
      'my_referral_code',
      prefs.getString('my_referral_code') ?? 'DEMO786',
    );
    if (!mounted) return;
    _goToHome();
  }

  void _goToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const Part2HomePreview()),
    );
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
                // App Logo / Header
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
                  'ऐप्स टेस्ट करें, 10 मिनट खेलें और कॉइन कमाएं!',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),

                // Main Card (Single Form Container)
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
                        // Toggle Switch: Login vs Sign Up
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
                                  onTap: () => setState(() => isLoginMode = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                                  onTap: () => setState(() => isLoginMode = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
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

                        // 1. Full Name (केवल Sign Up में दिखेगा)
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

                        // 2. Play Store Gmail ID
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

                        // 3. Password
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
                        const SizedBox(height: 14),

                        // 4. Referral Code (केवल Sign Up में)
                        if (!isLoginMode) ...[
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

                        // Submit Button
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
                                ? const CircularProgressIndicator(color: Colors.white)
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

                        const SizedBox(height: 12),

                        // Quick Demo Login Button (टेस्टिंग आसान बनाने के लिए)
                        OutlinedButton.icon(
                          onPressed: isLoading ? null : _demoLogin,
                          icon: const Icon(Icons.flash_on, color: Colors.orange),
                          label: const Text('1-Click Demo Account से टेस्ट करें'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
