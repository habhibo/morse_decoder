import 'package:flutter/material.dart';
import 'main_screen.dart';

class LoadingScreen extends StatefulWidget {
  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF327D63), // Updated to match Figma color
      body: Center(
        child: Container(
          width: 177.4,
          height: 177.4,
          decoration: BoxDecoration(
            color: Color(0xFF5BA188), // App icon background color
            borderRadius: BorderRadius.circular(45.39), // iOS app icon radius
          ),
          child: Center(
            child: Container(
              width: 130.19*1.4,
              height: 117.28*1.4,
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}