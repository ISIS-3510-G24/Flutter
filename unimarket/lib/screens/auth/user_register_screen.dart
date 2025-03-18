import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/data/firebase_dao.dart';

class UserRegister extends StatefulWidget {
  final VoidCallback showLoginPage;
  const UserRegister({super.key, required this.showLoginPage});
  
  
  @override
  State<UserRegister> createState() => _UserRegisterState();
}

class _UserRegisterState extends State<UserRegister> {
  String? _selectedMajor;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _confirmpasswordController = TextEditingController();
  final FirebaseDAO _firebaseDAO = FirebaseDAO();



  
  @override
  void dispose(){
    _emailController.dispose();
    _passwordController.dispose();
    _bioController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future _signUp() async{
    final email = _emailController.text;
    final bio = _bioController.text;
    final password = _passwordController.text;
    final displayName = _displayNameController.text;
    final passwordconfirm = _confirmpasswordController.text;
    String? _selectedMajor;
    if (_selectedMajor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a major")),
      );
      return;
    }

    if (confirmPassword()){
      await _firebaseDAO.createUser(email, password, bio, displayName, _selectedMajor);
    }


    

  }

  bool confirmPassword(){
    if (_passwordController.text.trim() == _confirmpasswordController.text.trim()){
      return true;
    }
    else {
      return false;
    }
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
                      "Name",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                ),
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

                      return DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: "Select Major",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        value: _selectedMajor, // Selected major value
                        items: snapshot.data!.map((majorId) {
                          return DropdownMenuItem(
                            value: majorId,
                            child: Text(majorId), // Display major ID (or change to name if needed)
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedMajor = newValue; // Update selected major
                          });
                        },
                      );
                    },
                  ),
                ),
                // Login button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: GestureDetector(
                    onTap: () {
                      print("Email: ${_emailController.text}");
                      print("Password: ${_passwordController.text}");
                      _signUp();
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
            
                // Sign Up Text
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
      ),
    );
  }
}