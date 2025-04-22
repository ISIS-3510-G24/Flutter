import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:unimarket/services/auth_storage_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback showRegisterPage;
  const LoginScreen({super.key, required this.showRegisterPage});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseDAO _firebaseDAO = FirebaseDAO();
  Future<bool> _savedCredentialsFuture = Future.value(false);
  bool _biometricsAvailable = false;

 @override
void initState() {
  super.initState();
  _checkBiometrics();
  _loadSavedEmail();
  _savedCredentialsFuture = BiometricAuthService.hasSavedCredentials();
}

  Future<void> _checkBiometrics() async {
    _biometricsAvailable = await BiometricAuthService.hasBiometrics;
    setState(() {});
  }

  Future<void> _loadSavedEmail() async {
    if (await BiometricAuthService.hasSavedCredentials()) {
      final credentials = await BiometricAuthService.getSavedCredentials();
      if (mounted) {
        setState(() {
          _emailController.text = credentials['email'] ?? '';
        });
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    if (!_biometricsAvailable) return;

    final authenticated = await BiometricAuthService.authenticate();
    if (!authenticated) return;

    if (await BiometricAuthService.hasSavedCredentials()) {
      final credentials = await BiometricAuthService.getSavedCredentials();
      await _attemptLogin(credentials['email']!, credentials['password']!);
    }
  }

  Future<void> _attemptLogin(String email, String password) async {
    try {
      // Try online login first
      final success = await _firebaseDAO.signIn(email, password);
      
      if (success && mounted) {
        // Save credentials for future biometric login
        await BiometricAuthService.saveCredentials(email, password);
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showLoginError();
      }
    } catch (e) {
      // If online fails, check if credentials match saved ones
      final savedCreds = await BiometricAuthService.getSavedCredentials();
      if (savedCreds['email'] == email && savedCreds['password'] == password) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
          _showOfflineWarning();
        }
      } else {
        _showLoginError();
      }
    }
  }

  void _showOfflineWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offline Mode'),
        content: const Text('You are using the app in offline mode. Some features may be limited.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLoginError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Failed'),
        content: const Text('Invalid credentials or no internet connection'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }


  @override
  void dispose(){
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Color(0xFFf1f1f1),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // UniMarket image
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                  child: Image.asset(
                    'assets/images/PlainLogoWithBackground.png',
                    width: double.infinity,
                    height: 300,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                    "Welcome!",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 40,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
            
                // Username textbox
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          hintText: "Username",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
            
                // Password Textbox
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: "Password",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
            
                // Login button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: GestureDetector(
                    onTap: () async {
                      debugPrint("Login attempt with email: ${_emailController.text}");
                      await _attemptLogin(
                        _emailController.text.trim(),
                        _passwordController.text.trim(),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Color(0xFF66B7EF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          "Login",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
            
                // Biometric Login Button (conditionally shown)
                FutureBuilder<bool>(
                future: _savedCredentialsFuture,
                builder: (context, snapshot) {
                  final hasSavedCredentials = snapshot.data ?? false;
                  
                  if (_biometricsAvailable && hasSavedCredentials) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: GestureDetector(
                        onTap: _handleBiometricLogin,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Color(0xFF66B7EF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.fingerprint,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "Login with Biometrics",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
                const SizedBox(height: 10),
            
                // Sign Up Text
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Not a member?",
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(width: 5),
                    GestureDetector(
                      onTap: widget.showRegisterPage,
                      child: Text(
                        "Register now",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


