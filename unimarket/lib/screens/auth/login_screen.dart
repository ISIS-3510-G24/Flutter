import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/services/auth_storage_service.dart';
import 'package:unimarket/services/connectivity_service.dart';


class LoginScreen extends StatefulWidget {
  final VoidCallback showRegisterPage;
  const LoginScreen({super.key, required this.showRegisterPage});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ConnectivityService _connectivityService = ConnectivityService();
  final FirebaseDAO _firebaseDAO = FirebaseDAO();
  bool _isCheckingConnectivity = false;
  bool _isOffline = false;
  bool _hasInternetAccess = true;
  Future<bool> _savedCredentialsFuture = Future.value(false);
   StreamSubscription? _connectivitySubscription;
  bool _biometricsAvailable = false;

 @override
void initState() {
  super.initState();
  _checkBiometrics();
  _checkConnectivity();
  _loadSavedEmail();
  _hasInternetAccess = _connectivityService.hasInternetAccess;
  _isCheckingConnectivity = _connectivityService.isChecking;
  _savedCredentialsFuture = BiometricAuthService.hasSavedCredentials();

  _connectivitySubscription = _connectivityService.connectivityStream.listen((hasInternet) {
      if (mounted) {
        setState(() {
          _hasInternetAccess = hasInternet;
        });
        
      }
    });
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
  // First validate inputs
  if (email.isEmpty || password.isEmpty) {
    _showLoginError('Please enter both email and password');
    return;
  }

  try {
    // Try online login first with timeout
    final success = await _firebaseDAO.signIn(email, password)
      .timeout(const Duration(seconds: 10));
    
    if (success && mounted) {
      debugPrint('Online login successful');
      await BiometricAuthService.saveCredentials(email, password);
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }
    
    _checkOfflineCredentials(email, password);
  } on TimeoutException {
    debugPrint('Login timed out - checking offline credentials');
    _checkOfflineCredentials(email, password);
  } on SocketException {
    debugPrint('No internet connection - checking offline credentials');
    _checkOfflineCredentials(email, password);
  } catch (e) {
    debugPrint('Login error: $e');
    _showLoginError('Login failed. Please try again.');
  }
}

  Future<void> _checkConnectivity() async {
    
    // Check connectivity
    final bool hasInternet = await _connectivityService.checkConnectivity();
    
    if (mounted) {
      setState(() {
        _isOffline = !hasInternet;
      });
      
    }
  }
   
  void _handleRetryPressed() async {
    // Force a connectivity check
    bool hasInternet = await _connectivityService.checkConnectivity();
    
    // If there's internet, refresh data
    
  }
  



Future<void> _checkOfflineCredentials(String email, String password) async {
  try {
    debugPrint('Checking saved credentials for offline login');
    final savedCreds = await BiometricAuthService.getSavedCredentials();
    debugPrint('Email: ${savedCreds['email']}');
    debugPrint('Password: ${savedCreds['password']}');
    if (savedCreds['email'] == email && savedCreds['password'] == password) {
      if (mounted) {
        debugPrint('Offline login successful');
        Navigator.pushReplacementNamed(context, '/home');
        _showOfflineWarning();
      }
    } else {
      debugPrint('Offline login failed - credentials mismatch');
      _showLoginError('No internet connection and no matching saved credentials');
    }
  } catch (e) {
    debugPrint('Offline check error: $e');
    _showLoginError('Could not verify credentials offline');
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

  void _showLoginError(String errorMessage) {
    if (!mounted) return;
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Login Failed'),
        content: Text(errorMessage),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
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
  // Get current connectivity state - make sure you have these variables defined in your state
    bool isOffline = !_hasInternetAccess;
  
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Color(0xFFf1f1f1),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add the connection status banner at the top
              if (isOffline || _isCheckingConnectivity)
                Container(
                  width: double.infinity,
                  color: CupertinoColors.systemYellow.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    children: [
                      _isCheckingConnectivity 
                          ? CupertinoActivityIndicator(radius: 8)
                          : const Icon(
                              CupertinoIcons.exclamationmark_triangle,
                              size: 16,
                              color: CupertinoColors.systemYellow,
                            ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isCheckingConnectivity
                              ? "Checking internet connection..."
                              : "No internet connection. Some features may not work.",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      ),
                      if (!_isCheckingConnectivity)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minSize: 0,
                          child: Text(
                            "Retry",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.blue, // Changed to Material's blue
                            ),
                          ),
                          onPressed: _handleRetryPressed,
                        ),
                    ],
                  ),
                ),

              // Rest of your existing content
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


