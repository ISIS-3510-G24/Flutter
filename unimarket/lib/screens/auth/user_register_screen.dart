import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/services/auth_storage_service.dart';

class UserRegister extends StatefulWidget {
  final VoidCallback showLoginPage;
  const UserRegister({super.key, required this.showLoginPage});
  
  
  @override
  State<UserRegister> createState() => _UserRegisterState();
}

class _UserRegisterState extends State<UserRegister> {
  String? selectedMajor;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _confirmpasswordController = TextEditingController();
  final FirebaseDAO _firebaseDAO = FirebaseDAO();
  bool _isConnected = true;

  
void _showErrorAlert(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
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
  void initState() {
    super.initState();
    _checkInternetConnection(); 
  }

  @override
  void dispose(){
    _emailController.dispose();
    _passwordController.dispose();
    _bioController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }
Future<bool> _signUp() async {
  final email = _emailController.text;
  final bio = _bioController.text;
  final password = _passwordController.text;
  final displayName = _displayNameController.text;
  final passwordConfirm = _confirmpasswordController.text;

  // Input validation
  if (selectedMajor == null) {
    _showErrorAlert('Please select a major');
    return false;
  }
  if (email.trim().isEmpty) {
    _showErrorAlert('Please type in your email address');
    return false;
  }
  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email.trim())) {
    _showErrorAlert("Please type in a valid email address");
    return false;
  }
  if (bio.trim().isEmpty) {
    _showErrorAlert('Please write something for your bio');
    return false;
  }
  if (displayName.trim().isEmpty) {
    _showErrorAlert('Please type the name you want others to see you with');
    return false;
  }
  if (password.trim().isEmpty || passwordConfirm.trim().isEmpty) {
    _showErrorAlert('Please type in your password and its confirmation');
    return false;
  }
  if (!confirmPassword(password.trim(), passwordConfirm.trim())) {
    _showErrorAlert('Passwords do not match');
    return false;
  }

  try {
    // Check internet connection first
    final hasConnection = await _checkInternetConnection();
    if (!hasConnection) {
      _showNoInternetPopup();
      return false;
    }

    await _firebaseDAO.createUser(
      email, 
      password, 
      bio, 
      displayName, 
      selectedMajor!
    );
    await BiometricAuthService.saveCredentials(email, password);
    return true;
  } on FirebaseAuthException catch (e) {
    _handleFirebaseAuthError(e);
    return false;
  } on SocketException catch (_) {
    _showNoInternetPopup();
    return false;
  } catch (e) {
    debugPrint("Signup error: $e");
    _showErrorAlert('An unexpected error occurred. Please try again.');
    return false;
  }
}

Future<bool> _checkInternetConnection() async {
  try {
    final result = await InternetAddress.lookup('google.com');
    final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    if (mounted) {
      setState(() {
        _isConnected = isConnected;
      });
    }
    return isConnected;
  } on SocketException catch (_) {
    if (mounted) {
      setState(() {
        _isConnected = false;
      });
    }
    return false;
  }
}

  void _showNoInternetPopup() {
    if (!mounted) return;
    
    setState(() {
      _isConnected = false;
    });
    
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text("No Internet Connection"),
        content: const Text("Please check your internet connection and try again."),
        actions: [
          CupertinoDialogAction(
            child: const Text("OK"),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

void _handleFirebaseAuthError(FirebaseAuthException e) {
  String errorMessage;
  
  switch (e.code) {
    case 'email-already-in-use':
      errorMessage = 'This email is already registered.';
      break;
    case 'invalid-email':
      errorMessage = 'The email address is invalid.';
      break;
    case 'operation-not-allowed':
      errorMessage = 'Email/password accounts are not enabled.';
      break;
    case 'weak-password':
      errorMessage = 'The password is too weak.';
      break;
    default:
      errorMessage = 'An error occurred during sign up.';
  }

  _showErrorAlert(errorMessage);
}

  bool confirmPassword(String password, String confirmPassword) {
    if (password == confirmPassword){
      return true;
    }
    else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    
    return CupertinoPageScaffold(
        backgroundColor: Color(0xFFf1f1f1),
        child: SafeArea(
          child: Column(
    children: [
      // Add this offline banner
      if (!_isConnected)
        Container(
          width: double.infinity,
          color: CupertinoColors.systemYellow.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 16,
                color: CupertinoColors.systemYellow,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "You are offline. Please connect to the internet to register correctly.",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 0,
                child: Text(
                  "Retry",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.blue,
                  ),
                ),
                onPressed: () async {
                  await _checkInternetConnection();
                },
              ),
            ],
          ),
        ),
      Expanded(
        child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                    "Sign up",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                      "Create an account to get started",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: const Color.fromARGB(255, 87, 87, 87),
                      ),
                    ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                      "Name - The name you want others to see",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                ),
                // display Name textbox
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
                      child: CupertinoTextField(
                        controller: _displayNameController,
                        placeholder: "Display name",
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: CupertinoColors.systemGrey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                //Email textbox
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                      "E-mail address",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                ),
                // Email
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
                      child: CupertinoTextField(
                        controller: _emailController,
                        placeholder: "Your email address",
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: CupertinoColors.systemGrey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                      "Password - has to have at least 6 characters",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                ),
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
                      child: CupertinoTextField(
                        controller: _passwordController,
                        placeholder: "Password",
                        obscureText: true,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: CupertinoColors.systemGrey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                      "Confirm Password",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                ),
                // Confirm password
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
                      child: CupertinoTextField(
                        controller: _confirmpasswordController,
                        placeholder: "Confirm Password",
                        obscureText: true,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: CupertinoColors.systemGrey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                      "Select your major  (only one)",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                ),
                 // Major Dropdown
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: FutureBuilder<List<String>>(
                    future: _firebaseDAO.fetchMajors(), // Fetch majors from FirebaseDAO
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator(); // Show a loading indicator
                      }
                      if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Text("Error loading majors or no majors found"); // Handle errors
                      }

                      return CupertinoButton(
                        child: Text(selectedMajor ?? "Select Major"),
                        onPressed: () {
                          showCupertinoModalPopup(
                            context: context,
                            builder: (context) => Container(
                              height: 250,
                              color: CupertinoColors.white,
                              child: CupertinoPicker(
                                itemExtent: 32,
                                onSelectedItemChanged: (index) {
                                  setState(() {
                                    selectedMajor = snapshot.data![index];
                                  });
                                },
                                children: snapshot.data!.map((major) => Text(major)).toList(),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                //Bio textbox
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                      "Bio - Write something fun!",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                ),
                
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
                      child: CupertinoTextField(
                        controller: _bioController,
                        placeholder: "Your own bio!",
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: CupertinoColors.systemGrey),
                          borderRadius: BorderRadius.circular(12),
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
                      print("Email: ${_emailController.text}");
                      print("Password: ${_passwordController.text}");
                      bool success = await _signUp();
                      if (success) {
                        showCupertinoDialog(
                          context: context,
                          builder: (context) => CupertinoAlertDialog(
                            title: Text("Success"),
                            content: Text("Sign-up successful!"),
                            actions: [
                              CupertinoDialogAction(
                                child: Text("Proceed to preferences"),
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.pushReplacementNamed(context, "/preferences");
                                },
                              ),
                            ],
                          ),
                        );
                      } 
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Color(0xFF66B7EF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          "Create Account",
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
                const SizedBox(height: 20),
            
                //la parte esta de abajo del sign up
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account?",
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(width: 5),
                    GestureDetector(
                      onTap: widget.showLoginPage,
                      child: Text(
                        "Login now",
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
          ]
        ),
      ),
    );
  }
}