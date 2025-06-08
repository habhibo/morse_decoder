import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:morse_decoder/screens/language_screen.dart';
import 'package:morse_decoder/models/favorite_message.dart'; // Import FavoritesManager
import 'dart:convert';
import 'package:flutter/services.dart'; // Import for Clipboard
import 'dart:math'; // Add this import

// Define Language class (unchanged)
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

class DecryptorScreen extends StatefulWidget {
  @override
  _DecryptorScreenState createState() => _DecryptorScreenState();
}

class _DecryptorScreenState extends State<DecryptorScreen> {
  CameraController? _cameraController;
  bool _isRecording = false;
  bool _isEnglish = true; // true for Morse-to-text, false for text-to-Morse
  String _translationText = 'The translation will be shown here';
  String _currentLanguage = 'English'; // Track selected language
  Map<String, String> _charToMorse = {}; // Character to Morse mapping
  Map<String, String> _morseToChar = {}; // Morse to character mapping
  String _detectedMorseCode = ''; // Detected Morse code
  Timer? _morseTimer; // Timeout for recording
  List<double> _flashDurations = []; // Store on/off durations for debugging
  bool _isFlashOn = false; // Track flash state
  DateTime? _lastChangeTime; // Time of last state change

  List<Language> languages = []; // Initialize as empty, will be populated by _loadLanguages
  final FavoritesManager _favoritesManager = FavoritesManager(); // Initialize FavoritesManager

  // Enhanced flash detection variables
  List<double> _luminanceHistory = [];
  static const int HISTORY_SIZE = 20; // Reduced for mobile performance
  double _baselineLuminance = 0.0;
  bool _baselineEstablished = false;
  double _lastLuminance = 0.0;
  List<double> _changeRates = [];
  static const int CHANGE_HISTORY_SIZE = 8;
  int _frameCount = 0;

  // Default English to Morse mapping using Unicode characters (consistent with translate_screen)
  final Map<String, String> _defaultEnglishToMorse = {
    'a': '·−', 'b': '−···', 'c': '−·−·', 'd': '−··', 'e': '·',
    'f': '··−·', 'g': '−−·', 'h': '····', 'i': '··', 'j': '·−−−',
    'k': '−·−', 'l': '·−··', 'm': '−−', 'n': '−·', 'o': '−−−',
    'p': '·−−·', 'q': '−−·−', 'r': '·−·', 's': '···', 't': '−',
    'u': '··−', 'v': '···−', 'w': '·−−', 'x': '−··−', 'y': '−·−−',
    'z': '−−··', '0': '−−−−−', '1': '·−−−−', '2': '··−−−', '3': '···−−',
    '4': '····−', '5': '·····', '6': '−····', '7': '−−···', '8': '−−−··',
    '9': '−−−−·', ' ': '/'
  };

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadAndInitializeLanguage();
    _loadFavorites(); // Load favorites when the screen initializes
  }

  Future<void> _loadFavorites() async {
    await _favoritesManager.loadFavorites();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras.first,
          ResolutionPreset.medium,
          enableAudio: false, // Explicitly disable audio capture
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      print('Error initializing camera: $e');
      setState(() {
        _translationText = 'Error initializing camera';
      });
    }
  }

  Future<void> _loadLanguages() async {
    final prefs = await SharedPreferences.getInstance();
    final String? languagesJson = prefs.getString('languages');
    List<Language> loadedLanguages = [];

    if (languagesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(languagesJson);
        loadedLanguages = decoded.map((e) => Language.fromJson(e)).toList();
      } catch (e) {
        print('Error decoding languages from SharedPreferences: $e');
      }
    }
    if (mounted) {
      setState(() {
        languages = loadedLanguages;
      });
    }
  }

  Future<void> _loadAndInitializeLanguage() async {
    await _loadLanguages();

    final prefs = await SharedPreferences.getInstance();
    final String? lastSelectedLanguageName = prefs.getString('lastSelectedLanguage');

    Language? languageToUse;
    if (lastSelectedLanguageName != null) {
      try {
        languageToUse = languages.firstWhere((lang) => lang.name == lastSelectedLanguageName);
      } catch (e) {
        languageToUse = null;
      }
    }

    if (languageToUse == null) {
      try {
        languageToUse = languages.firstWhere((lang) => lang.name == 'English');
      } catch (e) {
        print('Error: English language not found in loaded languages. Using default English mapping.');
        languageToUse = Language(name: 'English', category: 'Latin', charToMorse: _defaultEnglishToMorse);
      }
    }

    if (mounted) {
      setState(() {
        _currentLanguage = languageToUse!.name;
        // Use the language's mapping, fallback to default if empty
        _charToMorse = languageToUse.charToMorse.isNotEmpty ? languageToUse.charToMorse : _defaultEnglishToMorse;
        _morseToChar = _charToMorse.map((k, v) => MapEntry(v, k));
        _isEnglish = _currentLanguage != 'Morse Code';
      });
    }
  }

  void _showLanguageModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LanguageScreen(
        onLanguageSelected: (languageName, charToMorse) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('lastSelectedLanguage', languageName);
          setState(() {
            _currentLanguage = languageName;
            // Use the provided mapping, fallback to default if empty
            _charToMorse = charToMorse.isNotEmpty ? charToMorse : _defaultEnglishToMorse;
            _morseToChar = _charToMorse.map((k, v) => MapEntry(v, k));
            _isEnglish = languageName != 'Morse Code';
            _translationText = 'The translation will be shown here';
            _detectedMorseCode = '';
            _translate();
          });
        },
      ),
    );
  }

  void _toggleLanguage() {
    setState(() {
      _isEnglish = !_isEnglish;
      _translationText = 'The translation will be shown here';
      _detectedMorseCode = '';
      _translate();
    });
  }

  void _translate() {
    setState(() {
      if (_detectedMorseCode.isEmpty) {
        _translationText = 'The translation will be shown here';
        return;
      }

      if (_isEnglish) {
        // Morse to text translation
        print('Detected Morse Code: $_detectedMorseCode'); // Debug print
        print('Morse to Char mapping: $_morseToChar'); // Debug print

        _translationText = _detectedMorseCode
            .split('/') // Split by word separators
            .map((morseWord) {
          return morseWord
              .trim()
              .split(' ') // Split by character separators
              .map((morse) {
            final trimmedMorse = morse.trim();
            if (trimmedMorse.isEmpty) return '';
            final char = _morseToChar[trimmedMorse];
            print('Morse: "$trimmedMorse" -> Char: "$char"'); // Debug print
            return char ?? '?';
          })
              .where((char) => char.isNotEmpty)
              .join('');
        })
            .join(' ');
      } else {
        // Text to Morse translation (not relevant for flash detection)
        _translationText = _detectedMorseCode;
      }

      print('Final translation: $_translationText'); // Debug print
    });
  }

  // Replace your existing _processCameraFrame method with this enhanced version:
  void _processCameraFrame(CameraImage image) {
    img.Image? convertedImage = _convertCameraImage(image);
    if (convertedImage == null) return;

    // Use center-focused ROI for better flash detection
    double luminance = _calculateROILuminance(convertedImage);

    // Enhanced flash detection using multiple methods
    bool isCurrentlyOn = _detectFlashEnhanced(luminance);

    if (_lastChangeTime == null) {
      _lastChangeTime = DateTime.now();
      _isFlashOn = isCurrentlyOn;
      return;
    }

    // Check if flash state changed
    if (isCurrentlyOn != _isFlashOn) {
      double duration = DateTime.now().difference(_lastChangeTime!).inMilliseconds / 1000.0;

      setState(() {
        if (_isFlashOn) {
          // Previous state was ON - add dots and dashes
          if (duration >= 0.8 && duration <= 1.6) { // Adjusted for your timing
            _detectedMorseCode += '·';
          } else if (duration >= 2.0 && duration <= 3.0) { // Adjusted for your timing
            _detectedMorseCode += '−';
          }
        } else {
          // Previous state was OFF - add separators
          if (duration >= 0.0 && duration <= 0.7) { // Element gap
            // Just a gap between elements, no separator needed
          } else if (duration >= 1 && duration <= 2.5) { // Character gap
            _detectedMorseCode += ' ';
          } else if (duration >= 2.8 && duration <= 4.0) { // Word gap
            _detectedMorseCode += '/';
          }
        }

        _flashDurations.add(duration);
        _isFlashOn = isCurrentlyOn;
        _lastChangeTime = DateTime.now();
        _translate();
      });
    }
  }

  img.Image? _convertCameraImage(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      final img.Image converted = img.Image(width: width, height: height);

      // YUV420 to RGB conversion
      final yBuffer = image.planes[0].bytes;
      final uBuffer = image.planes[1].bytes;
      final vBuffer = image.planes[2].bytes;

      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int uvIndex = (x ~/ 2) * uvPixelStride + (y ~/ 2) * uvRowStride;
          final int index = y * image.planes[0].bytesPerRow + x;

          final yp = yBuffer[index];
          final up = uBuffer[uvIndex];
          final vp = vBuffer[uvIndex];

          // YUV to RGB conversion
          int r = (yp + 1.402 * (vp - 128)).round().clamp(0, 255);
          int g = (yp - 0.344 * (up - 128) - 0.714 * (vp - 128)).round().clamp(0, 255);
          int b = (yp + 1.772 * (up - 128)).round().clamp(0, 255);

          converted.setPixelRgba(x, y, r, g, b, 255);
        }
      }
      return converted;
    } catch (e) {
      print('Error converting image: $e');
      return null;
    }
  }

  // Enhanced ROI-based luminance calculation
  double _calculateROILuminance(img.Image image) {
    int centerX = image.width ~/ 2;
    int centerY = image.height ~/ 2;
    int roiSize = min(image.width, image.height) ~/ 6; // Focus on center area

    double totalLuminance = 0;
    int pixelCount = 0;

    // Sample every 2nd pixel for performance
    for (int y = centerY - roiSize; y < centerY + roiSize; y += 2) {
      for (int x = centerX - roiSize; x < centerX + roiSize; x += 2) {
        if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
          final pixel = image.getPixel(x, y);
          final luminance = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
          totalLuminance += luminance;
          pixelCount++;
        }
      }
    }

    return pixelCount > 0 ? (totalLuminance / pixelCount) / 255.0 : 0.0;
  }

  // Modified flash detection to use a fixed threshold of 0.6
  bool _detectFlashEnhanced(double currentLuminance) {
    // Assume flash is on if luminance is > 0.6, otherwise off.
    return currentLuminance > 0.7;
  }

  // Add this method to reset detection state when starting/stopping recording
  void _resetFlashDetection() {
    _luminanceHistory.clear();
    _changeRates.clear();
    _baselineEstablished = false;
    _baselineLuminance = 0.0;
    _lastLuminance = 0.0;
    _frameCount = 0;
  }

  // Update your _toggleRecording method to reset detection state:
  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (_isRecording) {
        _detectedMorseCode = '';
        _flashDurations = [];
        _lastChangeTime = null;
        _isFlashOn = false;
        _resetFlashDetection(); // Add this line

        _cameraController?.startImageStream(_processCameraFrame).catchError((e) {
          print('Error starting image stream: $e');
          setState(() {
            _isRecording = false;
            _translationText = 'Error starting camera stream';
          });
        });

        _morseTimer = Timer(Duration(seconds: 300), () {
          if (_isRecording) {
            _toggleRecording();
          }
        });
      } else {
        _cameraController?.stopImageStream().catchError((e) {
          print('Error stopping image stream: $e');
        });
        _morseTimer?.cancel();
        _detectedMorseCode = '';
        _translationText = 'The translation will be shown here';
        _flashDurations = [];
        _lastChangeTime = null;
        _resetFlashDetection(); // Add this line
      }
    });
  }

  void _showGuide() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
          child: Container(
            width: 320,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Information',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Container(
                  width: 300,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/guide_image.png',
                      width: 300,
                      height: 120,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.image_not_supported, color: Colors.red, size: 50);
                      },
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'With this function, you can easily receive a signal from a distance and decipher it. To do this, you need to point the camera at the light source and hold it in the caper\'s field of view to start speech recognition. After that, the app will start translating the received information into the language of your choice.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.left,
                ),
                SizedBox(height: 16),
                Text(
                  'To send a message in this way to another person, you can use the function of playing the cipher with the device\'s flashlight on the translation screen.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.left,
                ),
                SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFDBAA39),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: Text(
                      'Back to the decryptor',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Method to copy the translated text
  void _copyTranslationText() {
    if (_translationText == 'The translation will be shown here' || _translationText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No text to copy.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: _translationText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Translated text copied to clipboard!'),
        backgroundColor: Color(0xFF4CB0D9),
      ),
    );
  }

  // Method to save the translation to favorites
  Future<void> _saveToFavorites() async {
    if (_translationText == 'The translation will be shown here' || _translationText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No translation to save to favorites.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_favoritesManager.isTextInFavorites(_translationText)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This message is already in favorites'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // In decryptor, detectedMorseCode is the "input" and _translationText is the "translated"
    // Since we are detecting Morse code and translating to text,
    // the original text in the favorite will be _translationText and morseText will be _detectedMorseCode.
    bool isRTL = RegExp(r'[\u0600-\u06FF]').hasMatch(_translationText); // Check if translated text is RTL

    await _favoritesManager.addFavorite(
      _translationText, // This is the human-readable text
      _detectedMorseCode, // This is the Morse code
      isRTL: isRTL,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved to favorites!'),
        backgroundColor: Color(0xFF4CB0D9),
      ),
    );
  }


  Widget _buildCornerBracket({
    required bool topLeft,
    required bool topRight,
    required bool bottomLeft,
    required bool bottomRight,
    required Color color,
  }) {
    return CustomPaint(
      size: Size(20, 20),
      painter: CornerBracketPainter(
        topLeft: topLeft,
        topRight: topRight,
        bottomLeft: bottomLeft,
        bottomRight: bottomRight,
        color: color,
        strokeWidth: 3,
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _morseTimer?.cancel();
    super.dispose();
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
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
                          onPressed: null,
                          child: Text(
                            _isEnglish ? 'Morse code' : _currentLanguage,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0B0E10),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFEDEDED),
                            foregroundColor: Color(0xFF0B0E10),
                            disabledBackgroundColor: Color(0xFFEDEDED),
                            disabledForegroundColor: Color(0xFF0B0E10),
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
                          onPressed: _showLanguageModal,
                          child: Text(
                            _isEnglish ? _currentLanguage : 'Morse code',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF4CB0D9),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Color(0xFF4CB0D9),
                            disabledForegroundColor: Colors.white,
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
              SizedBox(height: 13),
              Container(
                width: 314,
                height: 220,
                child: Stack(
                  children: [
                    Container(
                      width: 314,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: _cameraController != null && _cameraController!.value.isInitialized
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CameraPreview(_cameraController!),
                      )
                          : Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.camera_alt,
                            size: 48,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _buildCornerBracket(
                        topLeft: true,
                        topRight: false,
                        bottomLeft: false,
                        bottomRight: false,
                        color: _isRecording ? Color(0xFF4CB0D9) : Colors.grey,
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _buildCornerBracket(
                        topLeft: false,
                        topRight: true,
                        bottomLeft: false,
                        bottomRight: false,
                        color: _isRecording ? Color(0xFF4CB0D9) : Colors.grey,
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: _buildCornerBracket(
                        topLeft: false,
                        topRight: false,
                        bottomLeft: true,
                        bottomRight: false,
                        color: _isRecording ? Color(0xFF4CB0D9) : Colors.grey,
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: _buildCornerBracket(
                        topLeft: false,
                        topRight: false,
                        bottomLeft: false,
                        bottomRight: true,
                        color: _isRecording ? Color(0xFF4CB0D9) : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),

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
                          child: Text(
                            _translationText,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: _translationText == 'The translation will be shown here'
                                  ? Color(0xFFB7B7B7)
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(Icons.content_copy, color: Color(0xFFA6A6A6), size: 24),
                            onPressed: _copyTranslationText, // Connect to copy method
                          ),
                          SizedBox(width: 14),
                          IconButton(
                            icon: Icon(Icons.bookmark, color: Color(0xFFA6A6A6), size: 24),
                            onPressed: _saveToFavorites, // Connect to save to favorites method
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Spacer(),
              Container(
                width: double.infinity,
                height: 66,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      onTap: _toggleRecording,
                      child: Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          color: _isRecording ? Color(0xFF4CB0D9) : Color(0xFFEBEBEB),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: _isRecording ? 16 : 40,
                            height: _isRecording ? 16 : 40,
                            decoration: BoxDecoration(
                              color: _isRecording ? Color(0xFFEBEBEB) : Color(0xFF4CB0D9),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: MediaQuery.of(context).size.width * 0.25,
                      child: GestureDetector(
                        onTap: _showGuide,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(0xFFEBEBEB),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '?',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0B0E10),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class CornerBracketPainter extends CustomPainter {
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;
  final Color color;
  final double strokeWidth;

  CornerBracketPainter({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final bracketLength = size.width * 0.8;

    if (topLeft) {
      canvas.drawLine(Offset(0, bracketLength), Offset(0, 0), paint);
      canvas.drawLine(Offset(0, 0), Offset(bracketLength, 0), paint);
    }

    if (topRight) {
      canvas.drawLine(Offset(size.width - bracketLength, 0), Offset(size.width, 0), paint);
      canvas.drawLine(Offset(size.width, 0), Offset(size.width, bracketLength), paint);
    }

    if (bottomLeft) {
      canvas.drawLine(Offset(0, size.height - bracketLength), Offset(0, size.height), paint);
      canvas.drawLine(Offset(0, size.height), Offset(bracketLength, size.height), paint);
    }

    if (bottomRight) {
      canvas.drawLine(Offset(size.width - bracketLength, size.height), Offset(size.width, size.height), paint);
      canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - bracketLength), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}