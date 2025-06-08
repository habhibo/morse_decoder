import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:morse_decoder/models/favorite_message.dart';
import 'package:torch_light/torch_light.dart'; // Import for flashlight control
import 'package:vibration/vibration.dart'; // Import for advanced vibration control

class FavoriteScreen extends StatefulWidget {
  @override
  _FavoriteScreenState createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  final FavoritesManager _favoritesManager = FavoritesManager();
  List<FavoriteMessage> favoriteMessages = [];

  // Define timing constants for Morse code playback - UPDATED to match translate_screen
  static const int DOT_DURATION_MS = 1200; // Updated to match translate_screen
  static const int DASH_DURATION_MS = 2500; // Updated to match translate_screen
  static const int ELEMENT_GAP_MS = 500; // Same as translate_screen
  static const int CHAR_GAP_MS = 1500; // Updated to match translate_screen
  static const int WORD_GAP_MS = 2800; // Updated to match translate_screen

  Future<void>? _currentPlaybackFuture; // To manage concurrent playback calls
  bool _isPlaybackCancelled = false; // Flag to signal cancellation

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    await _favoritesManager.loadFavorites();
    setState(() {
      favoriteMessages = _favoritesManager.favoriteMessages;
    });
  }

  void _toggleFavorite(int messageId, String text) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Remove Favorite'),
          content: Text('Are you sure you want to remove "$text" from favorites?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('No'),
            ),
            TextButton(
              onPressed: () async {
                await _favoritesManager.removeFavorite(messageId);
                setState(() {
                  favoriteMessages = _favoritesManager.favoriteMessages;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Removed from favorites!'),
                    backgroundColor: Color(0xFF4CB0D9),
                  ),
                );
              },
              child: Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  // Common logic for playing Morse code via vibration or flash for a favorite message
  Future<void> _playMorseCodeForFavorite(String morseCode, bool isVibrate, bool isFlash) async {
    if (morseCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No Morse code to play.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check availability of features upfront
    bool? hasVibrator = isVibrate ? await Vibration.hasVibrator() : false;
    bool? hasTorch = isFlash ? await TorchLight.isTorchAvailable() : false;

    if (isVibrate && !(hasVibrator ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device does not have a vibrator.'),
          backgroundColor: Colors.red,
        ),
      );
      return; // Exit if no vibrator
    }
    if (isFlash && !(hasTorch ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device does not have a flashlight.'),
          backgroundColor: Colors.red,
        ),
      );
      return; // Exit if no flashlight
    }

    // --- LOGIC FOR STOPPING EXISTING PLAYBACK ---
    if (_currentPlaybackFuture != null) {
      // A playback is currently active. User wants to stop it.
      _isPlaybackCancelled = true; // Signal cancellation
      // Wait for the current playback to gracefully exit its loop and clean up.
      await _currentPlaybackFuture;
      // _currentPlaybackFuture will be set to null in the whenComplete block of the old future.
      // _isPlaybackCancelled will also be reset there.

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playback stopped.'),
          backgroundColor: Colors.orange, // Distinct color for stopping
        ),
      );
      return; // IMPORTANT: Exit the function, do NOT start a new playback.
    }
    // --- END LOGIC FOR STOPPING ---

    // If we reach here, it means no playback was active, so we start a new one.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isVibrate ? 'Vibrating Morse code...' : 'Flashing Morse code...'),
        backgroundColor: Color(0xFF4CB0D9),
      ),
    );

    // --- Start of new playback logic ---
    // Create the new Future and assign it to _currentPlaybackFuture
    _currentPlaybackFuture = Future(() async {
      final morseElements = morseCode.split(''); // Use the provided morseCode

      for (int i = 0; i < morseElements.length; i++) {
        if (_isPlaybackCancelled) {
          // If cancellation requested, break loop immediately
          break;
        }

        final element = morseElements[i];
        bool isLastElementOfSequence = (i == morseElements.length - 1);
        // Check if the next element is a separator (space or slash)
        bool nextElementIsSeparator = !isLastElementOfSequence &&
            (morseElements[i + 1] == ' ' || morseElements[i + 1] == '/');

        // FIXED: Now checks for '·' (middle dot) for dot and '−' (en dash) for dash to match translate_screen
        if (element == '·' || element == '−') {
          int duration = (element == '·') ? DOT_DURATION_MS : DASH_DURATION_MS;

          // Turn ON flashlight
          if (isFlash && (hasTorch ?? false)) {
            try {
              await TorchLight.enableTorch();
            } on Exception catch (e) {
              print('Error enabling torch: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not enable flashlight: ${e.toString().split(':')[0]}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
          // Trigger vibration
          if (isVibrate && (hasVibrator ?? false)) {
            try {
              await Vibration.vibrate(duration: duration);
            } on Exception catch (e) {
              print('Error vibrating: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not vibrate: ${e.toString().split(':')[0]}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }

          // Wait for the ON duration
          await Future.delayed(Duration(milliseconds: duration));

          if (_isPlaybackCancelled) { // Check again after delay
            break;
          }

          // Turn OFF flashlight after dot/dash
          if (isFlash && (hasTorch ?? false)) {
            try {
              await TorchLight.disableTorch();
            } on Exception catch (e) {
              print('Error disabling torch: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not disable flashlight: ${e.toString().split(':')[0]}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }

          // Handle implicit inter-element gap (between dots/dashes within the same character)
          // Only add gap if not the last element AND the next element is NOT a separator (space/slash)
          if (!isLastElementOfSequence && !nextElementIsSeparator) {
            await Future.delayed(Duration(milliseconds: ELEMENT_GAP_MS));
          }
        } else if (element == ' ') {
          // Inter-character gap
          await Future.delayed(Duration(milliseconds: CHAR_GAP_MS));
        } else if (element == '/') {
          // Inter-word gap
          await Future.delayed(Duration(milliseconds: WORD_GAP_MS));
        }

        if (_isPlaybackCancelled) { // Final check before next iteration
          break;
        }
      }
    }).whenComplete(() async {
      // This runs whether the Future completed normally or was cancelled.
      // Ensure flashlight is off at the very end of playback or upon cancellation.
      if (isFlash && (await TorchLight.isTorchAvailable() ?? false)) {
        try {
          await TorchLight.disableTorch();
        } on Exception catch (e) {
          print('Error ensuring torch is off: $e');
        }
      }
      _currentPlaybackFuture = null; // Clear the future reference
      _isPlaybackCancelled = false; // Reset the flag for future playbacks
    });
  }

  void _playVibration(FavoriteMessage message) async {
    await _playMorseCodeForFavorite(message.morseCode, true, false);
  }

  void _playFlash(FavoriteMessage message) async {
    await _playMorseCodeForFavorite(message.morseCode, false, true);
  }

  void _showMoreOptions(FavoriteMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 200,
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.copy),
                title: Text('Copy Text'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.text));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Text copied to clipboard!'),
                      backgroundColor: Color(0xFF4CB0D9),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.copy_all),
                title: Text('Copy Morse Code'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.morseCode));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Morse code copied to clipboard!'),
                      backgroundColor: Color(0xFF4CB0D9),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Text(
                    'Favorites',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Favorites List
                Expanded(
                  child: favoriteMessages.isEmpty
                      ? Center(
                    child: Text(
                      'No favorites yet!\nSave your translations to see them here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                  )
                      : ListView.builder(
                    itemCount: favoriteMessages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 25),
                        child: _buildFavoriteCard(favoriteMessages[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteCard(FavoriteMessage message) {
    return Container(
      width: 328,
      padding: EdgeInsets.fromLTRB(18, 15, 16, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Color(0xFFD9D9D9), width: 1),
      ),
      child: Column(
        children: [
          // Top section with text and favorite button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Column(
                    crossAxisAlignment: message.isRTL
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      // Main text
                      Container(
                        width: 241,
                        child: Text(
                          message.text,
                          style: TextStyle(
                            color: Color(0xFF0B0E10),
                            fontSize: 16,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: message.isRTL ? TextAlign.right : TextAlign.left,
                        ),
                      ),
                      SizedBox(height: 10),
                      // Morse code
                      Container(
                        width: 241,
                        child: Text(
                          message.morseCode,
                          style: TextStyle(
                            color: Color(0xFF0B0E10),
                            fontSize: 16,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Favorite button
              GestureDetector(
                onTap: () => _toggleFavorite(message.id, message.text),
                child: Container(
                  width: 32,
                  height: 32,
                  child: Icon(
                    Icons.bookmark,
                    color: Color(0xFFDBAA39),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 25),
          // Bottom section with action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side buttons
              Row(
                children: [
                  // Vibro button
                  GestureDetector(
                    onTap: () => _playVibration(message),
                    child: Container(
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.vibration,
                        color: Color(0xFF4CB0D9),
                        size: 20,
                      ),
                    ),
                  ),
                  SizedBox(width: 20),
                  // Lightning/Flash button
                  GestureDetector(
                    onTap: () => _playFlash(message),
                    child: Container(
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.flash_on,
                        color: Color(0xFF4CB0D9),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              // Right side button (more options)
              GestureDetector(
                onTap: () => _showMoreOptions(message),
                child: Container(
                  width: 32,
                  height: 32,
                  child: Icon(
                    Icons.more_horiz,
                    color: Color(0xFFA6A6A6),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}