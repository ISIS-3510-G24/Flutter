
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MainLogin extends StatelessWidget {
  const MainLogin({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          if (snapshot.hasData) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacementNamed(context, '/preferences');
            });
           
          } else {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacementNamed(context, '/authval');
              });
            
          }
        }
      return const Center(child: CircularProgressIndicator());
      },
    ),

    );
  }
}