import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:morse_decoder/models/favorite_message.dart'; // Assuming this path is correct
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torch_light/torch_light.dart';
import 'dart:ui';
import 'package:vibration/vibration.dart'; // Import for advanced vibration control
import 'dart:developer' as developer; // Added for logging

import 'package:morse_decoder/screens/language_screen.dart'; // Assuming this path is correct

class Language {
  String name;
  String category;
  Map<String, String> charToMorse;

  Language({required this.name, required this.category, required this.charToMorse});

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'charToMorse': charToMorse,
  };

  factory Language.fromJson(Map<String, dynamic> json) => Language(
    name: json['name'],
    category: json['category'],
    charToMorse: Map<String, String>.from(json['charToMorse']),
  );
}

class TranslateScreen extends StatefulWidget {
  final String? selectedLanguage;
  final Map<String, String>? charToMorse;

  TranslateScreen({Key? key, this.selectedLanguage, this.charToMorse}) : super(key: key);

  @override
  _TranslateScreenState createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final TextEditingController _inputController = TextEditingController();
  String _translation = 'The translation will be shown here';
  bool _isEnglish = true;
  String _currentLanguage = 'English';
  Map<String, String> _charToMorse = {};
  Map<String, String> _morseToChar = {};
  final FocusNode _focusNode = FocusNode();
  final FavoritesManager _favoritesManager = FavoritesManager();

  static const int DOT_DURATION_MS = 1200;
  static const int DASH_DURATION_MS = 2500;
  static const int ELEMENT_GAP_MS = 500;
  static const int CHAR_GAP_MS = 1800;
  static const int WORD_GAP_MS = 3100;

  final Map<String, String> _englishToMorse = {
    'a': '·−', 'b': '−···', 'c': '−·−·', 'd': '−··', 'e': '·',
    'f': '··−·', 'g': '−−·', 'h': '····', 'i': '··', 'j': '·−−−',
    'k': '−·−', 'l': '·−··', 'm': '−−', 'n': '−·', 'o': '−−−',
    'p': '·−−·', 'q': '−−·−', 'r': '·−·', 's': '···', 't': '−',
    'u': '··−', 'v': '···−', 'w': '·−−', 'x': '−··−', 'y': '−·−−',
    'z': '−−··', '0': '−−−−−', '1': '·−−−−', '2': '··−−−', '3': '···−−',
    '4': '····−', '5': '·····', '6': '−····', '7': '−−···', '8': '−−−··',
    '9': '−−−−·', ' ': '/'
  };

  Future<void>? _currentPlaybackFuture;
  bool _isPlaybackCancelled = false;

  @override
  void initState() {
    super.initState();
    developer.log('[TranslateScreen LOG] initState called.');
    _loadFavorites();
    _initializeLanguage();
    _inputController.addListener(_translate);
  }

  @override
  void dispose() {
    developer.log('[TranslateScreen LOG] dispose called.');
    _inputController.removeListener(_translate);
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    developer.log('[TranslateScreen LOG] _loadFavorites called.');
    await _favoritesManager.loadFavorites();
  }

  void _initializeLanguage() async {
    developer.log('[TranslateScreen LOG] _initializeLanguage called.');
    final prefs = await SharedPreferences.getInstance();
    final String? lastSelectedLangName = prefs.getString('lastSelectedLanguage');
    developer.log('[TranslateScreen LOG] _initializeLanguage: lastSelectedLangName from prefs: $lastSelectedLangName');

    if (lastSelectedLangName != null) {
      await _loadLanguageFromPrefs(lastSelectedLangName);
    } else {
      setState(() {
        _currentLanguage = widget.selectedLanguage ?? 'English';
        _charToMorse = widget.charToMorse ?? _englishToMorse;
        _morseToChar = _charToMorse.map((k, v) => MapEntry(v, k));
        _isEnglish = _currentLanguage != 'Morse Code';
      });
      developer.log('[TranslateScreen LOG] _initializeLanguage: No last selected language found, defaulting to: $_currentLanguage');
      await prefs.setString('lastSelectedLanguage', _currentLanguage);
    }
  }

  Future<void> _loadLanguageFromPrefs(String languageName) async {
    developer.log('[TranslateScreen LOG] _loadLanguageFromPrefs called for: $languageName');
    final prefs = await SharedPreferences.getInstance();
    final String? languagesJson = prefs.getString('languages');
    developer.log('[TranslateScreen LOG] _loadLanguageFromPrefs: languagesJson exists: ${languagesJson != null}');

    List<Language> allLanguages = [];
    allLanguages.add(Language(name: 'Morse Code', category: 'Special', charToMorse: {}));
    allLanguages.add(Language(name: 'English', category: 'Latin', charToMorse: _englishToMorse));

    if (languagesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(languagesJson);
        allLanguages.addAll(decoded.map((e) => Language.fromJson(e)).toList());
        developer.log('[TranslateScreen LOG] _loadLanguageFromPrefs: Successfully decoded custom languages.');
      } catch (e) {
        developer.log('[TranslateScreen LOG] Error decoding languages from SharedPreferences: $e');
      }
    }

    final Language? selectedLang = allLanguages.firstWhere(
          (lang) => lang.name == languageName,
      orElse: () => Language(
        name: 'English',
        category: 'Latin',
        charToMorse: _englishToMorse,
      ),
    );

    if (mounted) {
      setState(() {
        _currentLanguage = selectedLang!.name;
        _charToMorse = selectedLang.charToMorse.isNotEmpty
            ? selectedLang.charToMorse
            : _englishToMorse; // Fallback for empty map (like Morse Code)
        _morseToChar = _charToMorse.map((k, v) => MapEntry(v, k));
        _isEnglish = _currentLanguage != 'Morse Code';
        developer.log('[TranslateScreen LOG] _loadLanguageFromPrefs: State updated for language: $_currentLanguage. CharToMorse map size: ${_charToMorse.length}.');
        if (_charToMorse.isNotEmpty) {
          developer.log('[TranslateScreen LOG] _loadLanguageFromPrefs: Example mappings: a->${_charToMorse['a']}, b->${_charToMorse['b']}');
        }
      });
      await prefs.setString('lastSelectedLanguage', _currentLanguage);
      developer.log('[TranslateScreen LOG] _loadLanguageFromPrefs: Saved lastSelectedLanguage to prefs: $_currentLanguage');
    } else {
      developer.log('[TranslateScreen LOG] _loadLanguageFromPrefs: Widget not mounted, skipping setState for $languageName.');
    }
    _translate(); // Re-trigger translation with new map
  }

  void _showLanguageModal() {
    developer.log('[TranslateScreen LOG] _showLanguageModal called.');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LanguageScreen(
        onLanguageSelected: (languageName, charToMorse) {
          developer.log('[TranslateScreen LOG] LanguageScreen onLanguageSelected callback triggered for: $languageName (secondary)');
        },
      ),
    ).then((result) async {
      developer.log('[TranslateScreen LOG] LanguageScreen dismissed. Result: $result (Type: ${result.runtimeType})');
      if (result != null && result is Map<String, dynamic>) {
        final String newSelectedLanguageName = result['name'];
        developer.log('[TranslateScreen LOG] LanguageScreen dismissed with explicit selection. New language name: $newSelectedLanguageName');
        await _loadLanguageFromPrefs(newSelectedLanguageName);
      } else {
        developer.log('[TranslateScreen LOG] LanguageScreen dismissed without explicit selection or specific data. Reloading current language: $_currentLanguage');
        await _loadLanguageFromPrefs(_currentLanguage);
      }
    });
  }

  void _toggleLanguage() {
    developer.log('[TranslateScreen LOG] _toggleLanguage called. From $_isEnglish to ${!_isEnglish}.');
    setState(() {
      final String currentInput = _inputController.text;
      final String currentTranslation = _translation;

      _isEnglish = !_isEnglish;

      if (_isEnglish) {
        _inputController.text = currentTranslation == 'The translation will be shown here' ? '' : currentTranslation;
        _translation = currentInput;
      } else {
        _translation = currentInput;
        _inputController.text = currentTranslation == 'The translation will be shown here' ? '' : currentTranslation;
      }
      _inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: _inputController.text.length),
      );
      _translate(); // Re-trigger translation with the new state
    });
  }

  void _translate() {
    developer.log('[TranslateScreen LOG] _translate called. Current language: $_currentLanguage. Input: "${_inputController.text}".');
    if (_charToMorse.isNotEmpty) {
      developer.log('[TranslateScreen LOG] _translate: Active _charToMorse sample: a->${_charToMorse['a']}, b->${_charToMorse['b']}');
    }

    setState(() {
      if (_inputController.text.isEmpty) {
        _translation = 'The translation will be shown here';
        return;
      }

      if (_isEnglish) {
        _translation = _inputController.text
            .split('')
            .map((char) => _charToMorse[char.toLowerCase()] ?? (char == ' ' ? '/' : ''))
            .where((morse) => morse.isNotEmpty)
            .join(' ');
      } else {
        _translation = _inputController.text
            .split('/')
            .map((morseWord) {
          return morseWord
              .trim()
              .split(' ')
              .map((morse) => _morseToChar[morse.trim()] ?? (morse.trim().isNotEmpty ? '?' : ''))
              .where((char) => char.isNotEmpty)
              .join('');
        }).join(' ');
      }
      developer.log('[TranslateScreen LOG] _translate: New translation: $_translation');
    });
  }

  void _copyInputText() {
    developer.log('[TranslateScreen LOG] _copyInputText called.');
    Clipboard.setData(ClipboardData(text: _inputController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Input text copied to clipboard!'),
        backgroundColor: Color(0xFF4CB0D9),
      ),
    );
  }

  void _copyTranslatedText() {
    developer.log('[TranslateScreen LOG] _copyTranslatedText called.');
    Clipboard.setData(ClipboardData(text: _translation));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Translated text copied to clipboard!'),
        backgroundColor: Color(0xFF4CB0D9),
      ),
    );
  }

  Future<void> _playMorseCode(bool isVibrate, bool isFlash) async {
    developer.log('[TranslateScreen LOG] _playMorseCode called. Vibrate: $isVibrate, Flash: $isFlash');

    String textToPlay;
    if (_isEnglish) {
      // If _isEnglish is true, input is English, output is Morse. Play the _translation (Morse).
      textToPlay = _translation;
    } else {
      // If _isEnglish is false, input is Morse, output is English. Play the _inputController.text (Morse).
      textToPlay = _inputController.text;
    }

    if (textToPlay == 'The translation will be shown here' || textToPlay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No Morse code to play.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    bool? hasVibrator = isVibrate ? await Vibration.hasVibrator() : false;
    bool? hasTorch = isFlash ? await TorchLight.isTorchAvailable() : false;
    developer.log('[TranslateScreen LOG] Playback: hasVibrator: $hasVibrator, hasTorch: $hasTorch');

    if (isVibrate && !(hasVibrator ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device does not have a vibrator.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (isFlash && !(hasTorch ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device does not have a flashlight.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_currentPlaybackFuture != null) {
      developer.log('[TranslateScreen LOG] Playback: Existing playback detected, attempting to cancel.');
      _isPlaybackCancelled = true;
      await _currentPlaybackFuture;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playback stopped.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isVibrate ? 'Vibrating Morse code...' : 'Flashing Morse code...'),
        backgroundColor: Color(0xFF4CB0D9),
      ),
    );

    _currentPlaybackFuture = Future(() async {
      final morseElements = textToPlay.split(''); // Use the determined textToPlay
      developer.log('[TranslateScreen LOG] Playback: Starting new playback for: "$textToPlay"');

      for (int i = 0; i < morseElements.length; i++) {
        if (_isPlaybackCancelled) {
          developer.log('[TranslateScreen LOG] Playback: Cancellation requested, breaking loop.');
          break;
        }

        final element = morseElements[i];
        bool isLastElementOfSequence = (i == morseElements.length - 1);
        bool nextElementIsSeparator = !isLastElementOfSequence &&
            (morseElements[i + 1] == ' ' || morseElements[i + 1] == '/');
        developer.log('[TranslateScreen LOG] Playback: Processing element "$element" (Index: $i)');

        if (element == '·' || element == '−') {
          int duration = (element == '·') ? DOT_DURATION_MS : DASH_DURATION_MS;
          developer.log('[TranslateScreen LOG] Playback: Element is dot/dash, duration: $duration ms');

          if (isFlash && (hasTorch ?? false)) {
            try {
              await TorchLight.enableTorch();
              developer.log('[TranslateScreen LOG] Playback: Torch ON');
            } on Exception catch (e) {
              developer.log('[TranslateScreen LOG] Error enabling torch: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not enable flashlight: ${e.toString().split(':')[0]}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
          if (isVibrate && (hasVibrator ?? false)) {
            try {
              await Vibration.vibrate(duration: duration);
              developer.log('[TranslateScreen LOG] Playback: Vibrating for $duration ms');
            } on Exception catch (e) {
              developer.log('[TranslateScreen LOG] Error vibrating: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not vibrate: ${e.toString().split(':')[0]}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }

          await Future.delayed(Duration(milliseconds: duration));
          developer.log('[TranslateScreen LOG] Playback: Waited for ON duration.');

          if (_isPlaybackCancelled) {
            break;
          }

          if (isFlash && (hasTorch ?? false)) {
            try {
              await TorchLight.disableTorch();
              developer.log('[TranslateScreen LOG] Playback: Torch OFF');
            } on Exception catch (e) {
              developer.log('[TranslateScreen LOG] Error disabling torch: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not disable flashlight: ${e.toString().split(':')[0]}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }

          if (!isLastElementOfSequence && !nextElementIsSeparator) {
            developer.log('[TranslateScreen LOG] Playback: Waiting for inter-element gap: $ELEMENT_GAP_MS ms');
            await Future.delayed(Duration(milliseconds: ELEMENT_GAP_MS));
          }
        } else if (element == ' ') {
          developer.log('[TranslateScreen LOG] Playback: Waiting for inter-character gap: $CHAR_GAP_MS ms');
          await Future.delayed(Duration(milliseconds: CHAR_GAP_MS));
        } else if (element == '/') {
          developer.log('[TranslateScreen LOG] Playback: Waiting for inter-word gap: $WORD_GAP_MS ms');
          await Future.delayed(Duration(milliseconds: WORD_GAP_MS));
        }

        if (_isPlaybackCancelled) {
          break;
        }
      }
    }).whenComplete(() async {
      developer.log('[TranslateScreen LOG] Playback: Playback completed or cancelled.');
      if (isFlash && (await TorchLight.isTorchAvailable() ?? false)) {
        try {
          await TorchLight.disableTorch();
          developer.log('[TranslateScreen LOG] Playback: Ensuring torch is off on complete/cancel.');
        } on Exception catch (e) {
          developer.log('[TranslateScreen LOG] Error ensuring torch is off on complete/cancel: $e');
        }
      }
      _currentPlaybackFuture = null;
      _isPlaybackCancelled = false;
      developer.log('[TranslateScreen LOG] Playback: Playback state reset.');
    });
  }

  void _vibrateTranslation() async {
    await _playMorseCode(true, false);
  }

  void _flashTranslation() async {
    await _playMorseCode(false, true);
  }

  void _clearInput() {
    developer.log('[TranslateScreen LOG] _clearInput called.');
    _inputController.clear();
    _translate();
  }

  void _deleteLastCharacter() {
    developer.log('[TranslateScreen LOG] _deleteLastCharacter called.');
    if (_inputController.text.isNotEmpty) {
      setState(() {
        _inputController.text = _inputController.text.substring(0, _inputController.text.length - 1);
        _inputController.selection = TextSelection.fromPosition(
          TextPosition(offset: _inputController.text.length),
        );
      });
      _translate();
    }
  }

  void _confirmInput() {
    developer.log('[TranslateScreen LOG] _confirmInput called. Unfocusing keyboard.');
    _focusNode.unfocus();
  }

  Future<void> _saveToFavorites(String inputText, String translatedText) async {
    developer.log('[TranslateScreen LOG] _saveToFavorites called. Input: "$inputText", Translation: "$translatedText"');
    if (inputText.isEmpty || translatedText == 'The translation will be shown here') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter text to save to favorites'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_favoritesManager.isTextInFavorites(inputText)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This message is already in favorites'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    bool isRTL = RegExp(r'[\u0600-\u06FF]').hasMatch(inputText);

    String originalText, morseText;
    if (_isEnglish) {
      originalText = inputText;
      morseText = translatedText;
    } else {
      originalText = translatedText;
      morseText = inputText;
    }

    await _favoritesManager.addFavorite(originalText, morseText, isRTL: isRTL);
    developer.log('[TranslateScreen LOG] _saveToFavorites: Message added to favorites.');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved to favorites!'),
        backgroundColor: Color(0xFF4CB0D9),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFFD9D9D9),
        elevation: 0,
        toolbarHeight: 0,
        title: Container(),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(height: 20),
                Container(
                  width: 304,
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Container(
                          height: 34,
                          child: ElevatedButton(
                            onPressed: _isEnglish ? _showLanguageModal : null,
                            child: Text(
                              _isEnglish ? _currentLanguage : 'Morse code',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _isEnglish ? Colors.white : Color(0xFF0B0E10),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isEnglish ? Color(0xFF4CB0D9) : Color(0xFFEDEDED),
                              foregroundColor: _isEnglish ? Colors.white : Color(0xFF0B0E10),
                              disabledBackgroundColor: _isEnglish ? Color(0xFF4CB0D9) : Color(0xFFEDEDED),
                              disabledForegroundColor: _isEnglish ? Color(0xFF0B0E10) : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Container(
                        width: 38,
                        height: 38,
                        child: ElevatedButton(
                          onPressed: _toggleLanguage,
                          child: Transform.rotate(
                            angle: 1.5708,
                            child: Icon(
                              Icons.swap_vert,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF4CB0D9),
                            shape: CircleBorder(),
                            padding: EdgeInsets.all(7),
                            elevation: 0,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 34,
                          child: ElevatedButton(
                            onPressed: _isEnglish ? null : _showLanguageModal,
                            child: Text(
                              _isEnglish ? 'Morse code' : _currentLanguage,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _isEnglish ? Color(0xFF0B0E10) : Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isEnglish ? Color(0xFFEDEDED) : Color(0xFF4CB0D9),
                              foregroundColor: _isEnglish ? Color(0xFF0B0E10) : Colors.white,
                              disabledBackgroundColor: _isEnglish ? Color(0xFFEDEDED) : Color(0xFF4CB0D9),
                              disabledForegroundColor: _isEnglish ? Color(0xFF0B0E10) : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 25),
                Container(
                  width: 328,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Color(0xFFD9D9D9)),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            decoration: InputDecoration(
                              hintText: 'Type your text here...',
                              hintStyle: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFFB7B7B7),
                              ),
                              border: InputBorder.none,
                            ),
                            focusNode: _focusNode,
                            maxLines: 3,
                            onChanged: (text) => _translate(),
                            keyboardType: _isEnglish ? TextInputType.text : TextInputType.multiline,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row( // This row will contain all left-aligned icons
                              children: [
                                if (!_isEnglish) // Show vibrate and flash buttons for Morse input
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.vibration, color: Color(0xFF4CB0D9), size: 24),
                                        onPressed: _vibrateTranslation,
                                      ),
                                      SizedBox(width: 14),
                                      IconButton(
                                        icon: Icon(Icons.flash_on, color: Color(0xFF4CB0D9), size: 24),
                                        onPressed: _flashTranslation,
                                      ),
                                    ],
                                  ),
                                // Always show the delete button
                                IconButton(
                                  icon: Icon(Icons.delete, color: Color(0xFFEB3208), size: 24),
                                  onPressed: _clearInput,
                                ),
                              ],
                            ),
                            Row( // This row contains copy and save buttons (right-aligned)
                              children: [
                                IconButton(
                                  icon: Icon(Icons.content_copy, color: Color(0xFFA6A6A6), size: 24),
                                  onPressed: _copyInputText,
                                ),
                                SizedBox(width: 14),
                                IconButton(
                                  icon: Icon(Icons.bookmark, color: Color(0xFFA6A6A6), size: 24),
                                  onPressed: () => _saveToFavorites(_inputController.text, _translation),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 25),
                Container(
                  width: 328,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Color(0xFFD9D9D9)),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: Text(
                                _translation,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: _translation == 'The translation will be shown here'
                                      ? Color(0xFFB7B7B7)
                                      : Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_isEnglish) // Show vibrate and flash for translated Morse code
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    child: IconButton(
                                      icon: Icon(Icons.vibration, color: Color(0xFF4CB0D9), size: 20),
                                      onPressed: _vibrateTranslation,
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                  SizedBox(width: 14),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    child: IconButton(
                                      icon: Icon(Icons.flash_on, color: Color(0xFF4CB0D9), size: 20),
                                      onPressed: _flashTranslation,
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              )
                            else // Only copy and save for translated English
                              Container(), // Empty container if no icons needed
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.content_copy, color: Color(0xFFA6A6A6), size: 24),
                                  onPressed: _copyTranslatedText,
                                ),
                                SizedBox(width: 14),
                                IconButton(
                                  icon: Icon(Icons.bookmark, color: Color(0xFFA6A6A6), size: 24),
                                  onPressed: () => _saveToFavorites(_inputController.text, _translation),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 28),
                Container(
                  height: 127,
                  child: !_isEnglish
                      ? Container(
                    width: 318,
                    height: 127,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMorseKeyboardButton('·', Color(0xFFCDCDCD)),
                                  ),
                                  SizedBox(width: 11),
                                  Expanded(
                                    child: _buildMorseKeyboardButton('−', Color(0xFFCDCDCD)),
                                  ),
                                ],
                              ),
                              SizedBox(height: 15),
                              _buildMorseKeyboardButton('/', Color(0xFFCDCDCD)),
                            ],
                          ),
                        ),
                        SizedBox(width: 9),
                        Column(
                          children: [
                            Container(
                              width: 69,
                              height: 54,
                              child: _buildMorseKeyboardButton('×', Color(0xFFCDCDCD), onTap: _deleteLastCharacter),
                            ),
                            SizedBox(height: 13),
                            Container(
                              width: 103,
                              height: 54,
                              child: _buildMorseKeyboardButton('OK', Color(0xFF4CB0D9), onTap: _confirmInput, isOk: true),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMorseKeyboardButton(String text, Color color, {VoidCallback? onTap, bool isOk = false}) {
    return Container(
      height: 52.61,
      child: ElevatedButton(
        onPressed: onTap ??
                () {
              setState(() {
                _inputController.text += text;
                _inputController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _inputController.text.length),
                );
              });
              _translate();
            },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
        ).copyWith(
          elevation: MaterialStateProperty.all(0),
          shadowColor: MaterialStateProperty.all(Colors.transparent),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: isOk ? Color(0xFF248BB5) : Colors.black.withOpacity(0.28),
                offset: Offset(0, 4),
                blurRadius: 0,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: text == '·'
                ? Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            )
                : text == '−'
                ? Container(
              width: 25,
              height: 2.5,
              color: Colors.white,
            )
                : text == '×'
                ? Icon(Icons.backspace, color: Colors.white, size: 24)
                : text == 'OK'
                ? Icon(Icons.check, color: Colors.white, size: 24)
                : Text(
              text,
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}