
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
//Esta es la clase que revisa si el dispositivo ya está registrado en firebase,
//si está, pasa directo a home, si no, va a la doble pantalla de login + sign in
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
              Navigator.pushReplacementNamed(context, '/home');
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