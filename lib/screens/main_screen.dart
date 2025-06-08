import 'package:flutter/material.dart';
import 'package:morse_decoder/screens/decryptor_screen.dart';
import 'package:morse_decoder/screens/favotite_screen.dart';
import 'package:morse_decoder/screens/language_screen.dart';
import 'translate_screen.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [
    TranslateScreen(),
    DecryptorScreen(),
    FavoriteScreen()
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        height: 101,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main navigation bar
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: Color(0xFF5BA188),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(23, 11, 23, 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                      icon: Icons.chat,
                      label: 'Translate',
                      isSelected: _selectedIndex == 0,
                      onTap: () => _onItemTapped(0),
                    ),
                    _buildNavItem(
                      icon: Icons.center_focus_strong,
                      label: 'Decryptor',
                      isSelected: _selectedIndex == 1,
                      onTap: () => _onItemTapped(1),
                    ),
                    _buildNavItem(
                      icon: Icons.bookmark,
                      label: 'Favourite',
                      isSelected: _selectedIndex == 2,
                      onTap: () => _onItemTapped(2),
                    ),
                  ],
                ),
              ),
            ),
            // Home indicator section
            Container(
              height: 21,
              color: Color(0xFF5BA188),
              child: Center(
                child: Container(
                  width: 153,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Color(0x61353535), // rgba(53, 53, 53, 0.38)
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 54,
          margin: EdgeInsets.symmetric(horizontal: 7.5),
          decoration: BoxDecoration(
            color: isSelected ? Color(0xFFDBAA39) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: Colors.white,
              ),
              SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}