import 'package:flutter/material.dart';
import 'package:unimarket/screens/auth/login_screen.dart';
import 'package:unimarket/screens/auth/user_register_screen.dart';

class AuthValidator extends StatefulWidget {
  const AuthValidator({super.key});

  @override
  State<AuthValidator> createState() => _AuthValidatorState();
}

class _AuthValidatorState extends State<AuthValidator> {
  bool isLoginPage = true;

  void toggleScreens(){
    setState(() {
      isLoginPage = !isLoginPage;
    });
  }
  @override
  Widget build(BuildContext context) {
    if (isLoginPage){
      return LoginScreen(showRegisterPage: toggleScreens,);
    }
    else{
      return UserRegister(showLoginPage: toggleScreens,);
    }
  }
}