import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:torch_light/torch_light.dart';
import 'package:vibration/vibration.dart';

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

class LanguageScreen extends StatefulWidget {
  final Function(String, Map<String, String>)? onLanguageSelected;

  const LanguageScreen({Key? key, this.onLanguageSelected}) : super(key: key);

  @override
  _LanguageScreenState createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String selectedLanguage = 'English';
  List<Language> languages = [];

  @override
  void initState() {
    super.initState();
    developer.log('[LanguageScreen LOG] initState called.');
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    developer.log('[LanguageScreen LOG] _loadLanguages called.');
    final prefs = await SharedPreferences.getInstance();
    final String? languagesJson = prefs.getString('languages');

    List<Language> loadedLanguages = [
      Language(
          name: 'English',
          category: 'Latin',
          charToMorse: {
            'a': '._', 'b': '_...', 'c': '_._.', 'd': '_..', 'e': '.',
            'f': '.._.', 'g': '__.', 'h': '....', 'i': '..', 'j': '.___',
            'k': '_._', 'l': '._..', 'm': '__', 'n': '_.', 'o': '___',
            'p': '.__.', 'q': '__._', 'r': '._.', 's': '...', 't': '_',
            'u': '.._', 'v': '..._', 'w': '.__', 'x': '_.._', 'y': '_.__',
            'z': '__..', '0': '_____', '1': '.____', '2': '..___', '3': '...__',
            '4': '...._', '5': '.....', '6': '_....', '7': '__...', '8': '___..',
            '9': '____.', ' ': '/'
          }
      ),
      Language(name: 'Morse Code', category: 'Special', charToMorse: {}),
    ];

    if (languagesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(languagesJson);
        loadedLanguages.addAll(decoded.map((e) => Language.fromJson(e)).toList());
        developer.log('[LanguageScreen LOG] Loaded custom languages from SharedPreferences, count: ${decoded.length}');
      } catch (e) {
        developer.log('[LanguageScreen LOG] Error decoding languages from SharedPreferences: $e');
      }
    } else {
      developer.log('[LanguageScreen LOG] No custom languages found in SharedPreferences.');
    }

    loadedLanguages.sort((a, b) {
      if (a.name == 'Morse Code') return -1;
      if (b.name == 'Morse Code') return 1;
      if (a.name == 'English') return -1;
      if (b.name == 'English') return 1;
      return a.name.compareTo(b.name);
    });

    if (mounted) {
      setState(() {
        languages = loadedLanguages;
        if (!languages.any((lang) => lang.name == selectedLanguage)) {
          selectedLanguage = 'English';
        }
      });
      developer.log('[LanguageScreen LOG] _loadLanguages: Languages list updated in state. Total count: ${languages.length}');
    }
  }

  Future<void> _saveLanguages() async {
    developer.log('[LanguageScreen LOG] _saveLanguages called.');
    final prefs = await SharedPreferences.getInstance();
    final languagesToSave = languages
        .where((lang) => lang.name != 'Morse Code' && lang.name != 'English')
        .map((e) => e.toJson())
        .toList();
    final languagesJson = jsonEncode(languagesToSave);
    developer.log('[LanguageScreen LOG] Saving languages JSON: $languagesJson');
    await prefs.setString('languages', languagesJson);
    developer.log('[LanguageScreen LOG] Languages saved successfully, count: ${languagesToSave.length}');
  }

  Future<void> _deleteLanguage(String languageName) async {
    developer.log('[LanguageScreen LOG] _deleteLanguage called for: $languageName');
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Language'),
        content: Text('Are you sure you want to delete "$languageName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) {
      developer.log('[LanguageScreen LOG] Deletion cancelled by user.');
      return;
    }

    if (mounted) {
      setState(() {
        languages.removeWhere((lang) => lang.name == languageName);
        if (selectedLanguage == languageName) {
          selectedLanguage = 'English';
        }
      });
      developer.log('[LanguageScreen LOG] Language removed from in-memory list: $languageName');
    }
    await _saveLanguages();
    await _loadLanguages();

    if (mounted) {
      developer.log('[LanguageScreen LOG] Popping LanguageScreen after deletion with new selected: $selectedLanguage');
      Navigator.pop(context, {
        'name': selectedLanguage,
        'charToMorse': languages.firstWhere((lang) => lang.name == selectedLanguage).charToMorse,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 60,
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text(
                    'Input language',
                    style: TextStyle(
                      color: Color(0xFF707070),
                      fontSize: 12,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 15),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.close,
                        color: Color(0xFF0B0E10),
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 450,
              child: Column(
                children: [
                  if (languages.isNotEmpty) ...[
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE6E6E6), width: 1),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildLanguageItem(languages[0], selectedLanguage == languages[0].name, false, isClickable: false),
                          _buildLanguageItem(languages[1], selectedLanguage == languages[1].name, false),
                        ],
                      ),
                    ),
                  ],
                  Expanded(
                    child: ListView.builder(
                      itemCount: languages.length > 2 ? languages.length - 2 : 0,
                      itemBuilder: (context, index) {
                        Language language = languages[index + 2];
                        return _buildLanguageItem(language, selectedLanguage == language.name, true);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  offset: Offset(0, -1),
                  blurRadius: 26,
                ),
              ],
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () async {
                    developer.log('[LanguageScreen LOG] Add new language button tapped. Showing NewLanguageScreen.');
                    final result = await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => NewLanguageScreen(),
                    );
                    if (result != null && result is Map<String, dynamic>) {
                      developer.log('[LanguageScreen LOG] NewLanguageScreen returned a result (new language saved).');
                      if (mounted) {
                        Navigator.pop(context, result);
                      }
                    } else {
                      developer.log('[LanguageScreen LOG] NewLanguageScreen dismissed without saving a new language.');
                      _loadLanguages();
                    }
                  },
                  child: Container(
                    width: 330,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Color(0xFF4CB0D9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Add new language',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 25),
                Container(
                  height: 21,
                  child: Center(
                    child: Container(
                      width: 153,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Color(0x61353535),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageItem(Language language, bool isSelected, bool hasActions, {bool isClickable = true}) {
    return GestureDetector(
      onTap: isClickable
          ? () {
        developer.log('[LanguageScreen LOG] Language selected: ${language.name}');
        if (mounted) {
          setState(() {
            selectedLanguage = language.name;
          });
          Navigator.pop(context, {
            'name': language.name,
            'charToMorse': language.charToMorse,
          });
        }
      }
          : null,
      child: Container(
        height: 55,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          border: isSelected
              ? Border(
            left: BorderSide(color: Color(0xFF4CB0D9), width: 4),
          )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              language.name,
              style: TextStyle(
                color: isSelected
                    ? Color(0xFF4CB0D9)
                    : (isClickable ? Color(0xFF0B0E10) : Color(0xFFA6A6A6)),
                fontSize: 16,
                fontFamily: 'Inter',
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (hasActions)
              Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      developer.log('[LanguageScreen LOG] Edit language button tapped for: ${language.name}. Showing NewLanguageScreen.');
                      final result = await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => NewLanguageScreen(
                          languageToEdit: language,
                        ),
                      );
                      if (result != null && result is Map<String, dynamic>) {
                        developer.log('[LanguageScreen LOG] NewLanguageScreen returned a result (language edited).');
                        if (mounted) {
                          Navigator.pop(context, result);
                        }
                      } else {
                        developer.log('[LanguageScreen LOG] NewLanguageScreen dismissed without saving changes or explicit selection.');
                        _loadLanguages();
                      }
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      margin: EdgeInsets.only(right: 15),
                      child: Icon(
                        Icons.edit,
                        color: Color(0xFFA6A6A6),
                        size: 16,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _deleteLanguage(language.name),
                    child: Container(
                      width: 24,
                      height: 24,
                      child: Icon(
                        Icons.delete,
                        color: Color(0xFFEB3208),
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class NewLanguageScreen extends StatefulWidget {
  final Language? languageToEdit;

  NewLanguageScreen({Key? key, this.languageToEdit}) : super(key: key);

  @override
  _NewLanguageScreenState createState() => _NewLanguageScreenState();
}

class _NewLanguageScreenState extends State<NewLanguageScreen> {
  TextEditingController _languageController = TextEditingController();
  bool _canContinue = false;

  @override
  void initState() {
    super.initState();
    developer.log('[LanguageScreen LOG] NewLanguageScreen: initState called.');
    if (widget.languageToEdit != null) {
      _languageController.text = widget.languageToEdit!.name;
      _canContinue = true;
      developer.log('[LanguageScreen LOG] NewLanguageScreen: Editing existing language: ${widget.languageToEdit!.name}');
    }
    _languageController.addListener(() {
      if (mounted) {
        setState(() {
          _canContinue = _languageController.text.isNotEmpty;
        });
      }
    });
  }

  @override
  void dispose() {
    developer.log('[LanguageScreen LOG] NewLanguageScreen: dispose called.');
    _languageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 60,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Text(
                          widget.languageToEdit != null ? 'Edit language' : 'New language',
                          style: TextStyle(
                            color: Color(0xFF707070),
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 15),
                        child: GestureDetector(
                          onTap: () {
                            developer.log('[LanguageScreen LOG] NewLanguageScreen: Close button tapped.');
                            Navigator.pop(context);
                          },
                          child: Container(
                              width: 32,
                              height: 32,
                              child: Icon(
                                Icons.close,
                                color: Color(0xFF0B0E10),
                                size: 16,
                              ),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 28),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                          child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                  color: Color(0xFF5BA188), borderRadius: BorderRadius.circular(100)))),
                      SizedBox(width: 5),
                      Expanded(
                          child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                  color: Color(0xFFEBEBEB), borderRadius: BorderRadius.circular(100)))),
                      SizedBox(width: 5),
                      Expanded(
                          child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                  color: Color(0xFFEBEBEB), borderRadius: BorderRadius.circular(100)))),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    developer.log('[LanguageScreen LOG] NewLanguageScreen: Back button tapped.');
                    Navigator.pop(context);
                  },
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios, size: 10, color: Color(0xFF838383)),
                        SizedBox(width: 4),
                        Text(
                          'Back',
                          style: TextStyle(
                            color: Color(0xFF838383),
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 80),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Color(0xFFD9D9D9)),
                    ),
                    child: TextField(
                      controller: _languageController,
                      decoration: InputDecoration(
                        hintText: 'Language name...',
                        hintStyle: TextStyle(
                          color: Color(0xFFA6A6A6),
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  offset: Offset(0, -1),
                  blurRadius: 26,
                ),
              ],
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _canContinue
                      ? () async {
                    developer.log('[LanguageScreen LOG] NewLanguageScreen: Continue button tapped. Showing CharacterCategoryScreen.');
                    final result = await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => CharacterCategoryScreen(
                        languageName: _languageController.text,
                        category: widget.languageToEdit?.category,
                        initialCharToMorse: widget.languageToEdit?.charToMorse,
                      ),
                    );
                    developer.log('[LanguageScreen LOG] NewLanguageScreen: CharacterCategoryScreen returned: $result');
                    Navigator.pop(context, result);
                  }
                      : null,
                  child: Container(
                    width: 330,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Color(0xFF4CB0D9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Opacity(
                      opacity: _canContinue ? 1.0 : 0.4,
                      child: Center(
                        child: Text(
                          'Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 25),
                Container(
                  height: 21,
                  child: Center(
                    child: Container(
                      width: 153,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Color(0x61353535),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CharacterCategoryScreen extends StatefulWidget {
  final String languageName;
  final String? category;
  final Map<String, String>? initialCharToMorse;

  CharacterCategoryScreen({
    Key? key,
    required this.languageName,
    this.category,
    this.initialCharToMorse,
  }) : super(key: key);

  @override
  _CharacterCategoryScreenState createState() => _CharacterCategoryScreenState();
}

class _CharacterCategoryScreenState extends State<CharacterCategoryScreen> {
  List<Map<String, String>> categories = [
    {'name': 'Latin', 'icon': 'Ls'},
    {'name': 'Cyrillic', 'icon': 'аб'},
    {'name': 'Arabic', 'icon': 'أبجد'},
    {'name': 'Other', 'icon': ''},
  ];
  String? selectedCategory;

  @override
  void initState() {
    super.initState();
    developer.log('[LanguageScreen LOG] CharacterCategoryScreen: initState called.');
    selectedCategory = widget.category;
    developer.log('[LanguageScreen LOG] CharacterCategoryScreen: Initial category: $selectedCategory');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 60,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Text(
                          'New language',
                          style: TextStyle(
                            color: Color(0xFF707070),
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 15),
                        child: GestureDetector(
                          onTap: () {
                            developer.log('[LanguageScreen LOG] CharacterCategoryScreen: Close button tapped.');
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            child: Icon(
                              Icons.close,
                              color: Color(0xFF0B0E10),
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 28),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                          child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                  color: Color(0xFF5BA188), borderRadius: BorderRadius.circular(100)))),
                      SizedBox(width: 5),
                      Expanded(
                          child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                  color: Color(0xFF5BA188), borderRadius: BorderRadius.circular(100)))),
                      SizedBox(width: 5),
                      Expanded(
                          child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                  color: Color(0xFFEBEBEB), borderRadius: BorderRadius.circular(100)))),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    developer.log('[LanguageScreen LOG] CharacterCategoryScreen: Back button tapped.');
                    Navigator.pop(context);
                  },
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios, size: 10, color: Color(0xFF838383)),
                        SizedBox(width: 4),
                        Text(
                          'Back',
                          style: TextStyle(
                            color: Color(0xFF838383),
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 40),
                Text(
                  'Select a character category',
                  style: TextStyle(
                    color: Color(0xFF0B0E10),
                    fontSize: 16,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: 22),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 60.5),
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 13,
                        mainAxisSpacing: 14,
                        childAspectRatio: 141 / 87,
                      ),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final isSelected = selectedCategory == category['name'];

                        return GestureDetector(
                          onTap: () {
                            developer.log('[LanguageScreen LOG] CharacterCategoryScreen: Category selected: ${category['name']}');
                            if (mounted) {
                              setState(() {
                                selectedCategory = category['name'];
                              });
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? Color(0xFF4CB0D9) : Color(0xFFEBEBEB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  child: Center(
                                    child: category['icon']!.isNotEmpty
                                        ? Text(
                                      category['icon']!,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Color(0xFF0B0E10),
                                        fontSize: 18,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                        : Container(),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  category['name']!,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Color(0xFF0B0E10),
                                    fontSize: 20,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  offset: Offset(0, -1),
                  blurRadius: 26,
                ),
              ],
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: selectedCategory != null
                      ? () async {
                    developer.log('[LanguageScreen LOG] CharacterCategoryScreen: Continue button tapped. Showing CharacterListScreen.');
                    final result = await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => CharacterListScreen(
                        languageName: widget.languageName,
                        category: selectedCategory!,
                        initialCharToMorse: widget.initialCharToMorse,
                      ),
                    );
                    developer.log('[LanguageScreen LOG] CharacterCategoryScreen: CharacterListScreen returned: $result');
                    Navigator.pop(context, result);
                  }
                      : null,
                  child: Container(
                    width: 330,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Color(0xFF4CB0D9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Opacity(
                      opacity: selectedCategory != null ? 1.0 : 0.4,
                      child: Center(
                        child: Text(
                          'Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 25),
                Container(
                  height: 21,
                  child: Center(
                    child: Container(
                      width: 153,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Color(0x61353535),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CharacterListScreen extends StatefulWidget {
  final String languageName;
  final String category;
  final Map<String, String>? initialCharToMorse;

  CharacterListScreen({
    Key? key,
    required this.languageName,
    required this.category,
    this.initialCharToMorse,
  }) : super(key: key);

  @override
  _CharacterListScreenState createState() => _CharacterListScreenState();
}

class _CharacterListScreenState extends State<CharacterListScreen> {
  List<Map<String, String>> characters = [];
  String currentMorseCode = '';
  TextEditingController _charController = TextEditingController();
  Map<String, String> editingCharacter = {};
  Future<void>? _currentPlaybackFuture;
  bool _isPlaybackCancelled = false;

  static const int DOT_DURATION_MS = 1200;
  static const int DASH_DURATION_MS = 2500;
  static const int ELEMENT_GAP_MS = 500;
  static const int CHAR_GAP_MS = 1500;
  static const int WORD_GAP_MS = 2800;

  @override
  void initState() {
    super.initState();
    developer.log('[LanguageScreen LOG] CharacterListScreen: initState called.');
    if (widget.initialCharToMorse != null) {
      characters = widget.initialCharToMorse!.entries
          .map((e) => {'char': e.key, 'code': e.value})
          .toList();
      developer.log('[LanguageScreen LOG] CharacterListScreen: Initial characters loaded: ${characters.length}');
    }
    _charController.addListener(() {
      if (_charController.text.length > 1) {
        _charController.text = _charController.text.substring(0, 1);
        _charController.selection = TextSelection.fromPosition(
          TextPosition(offset: _charController.text.length),
        );
      }
    });
  }

  @override
  void dispose() {
    developer.log('[LanguageScreen LOG] CharacterListScreen: dispose called.');
    _charController.dispose();
    _isPlaybackCancelled = true; // Cancel any ongoing playback
    super.dispose();
  }

  void _startEditing(Map<String, String> character) {
    developer.log('[LanguageScreen LOG] CharacterListScreen: _startEditing called for: ${character['char']}');
    if (mounted) {
      setState(() {
        editingCharacter = Map.from(character);
        _charController.text = character['char']!;
        currentMorseCode = character['code']!;
      });
    }
  }

  void _addOrUpdateCharacter() {
    developer.log('[LanguageScreen LOG] CharacterListScreen: _addOrUpdateCharacter called. Char: ${_charController.text}, Morse: $currentMorseCode');
    final String char = _charController.text.trim();
    final String morse = currentMorseCode.trim();

    if (char.isEmpty || morse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Character and Morse code cannot be empty')),
      );
      return;
    }

    if (mounted) {
      setState(() {
        final existingIndex = characters.indexWhere((element) => element['char'] == char);
        if (existingIndex != -1) {
          characters[existingIndex] = {'char': char, 'code': morse};
          developer.log('[LanguageScreen LOG] CharacterListScreen: Updated character: $char');
        } else {
          if (!characters.any((c) => c['char'] == char)) {
            characters.add({'char': char, 'code': morse});
            developer.log('[LanguageScreen LOG] CharacterListScreen: Added new character: $char');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Character "$char" already exists. Edit it instead.')),
            );
          }
        }
        _charController.clear();
        currentMorseCode = '';
        editingCharacter = {};
      });
    }
  }

  Future<void> _saveAndClose() async {
    developer.log('[LanguageScreen LOG] CharacterListScreen: _saveAndClose called.');
    if (characters.isNotEmpty) {
      developer.log('Saving language: ${widget.languageName}, category: ${widget.category}, characters: ${characters.length}');

      final newLanguage = Language(
        name: widget.languageName,
        category: widget.category,
        charToMorse: Map.fromEntries(characters.map((e) => MapEntry(e['char']!, e['code']!))),
      );

      final prefs = await SharedPreferences.getInstance();
      final String? languagesJson = prefs.getString('languages');
      List<Language> storedLanguages = [];

      if (languagesJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(languagesJson);
          storedLanguages = decoded.map((e) => Language.fromJson(e)).toList();
        } catch (e) {
          developer.log('[LanguageScreen LOG] CharacterListScreen: Error decoding existing languages from SharedPreferences: $e');
        }
      }

      final existingIndex = storedLanguages.indexWhere((lang) => lang.name == newLanguage.name);
      if (existingIndex != -1) {
        storedLanguages[existingIndex] = newLanguage;
        developer.log('[LanguageScreen LOG] CharacterListScreen: Updated existing language: ${newLanguage.name}');
      } else {
        storedLanguages.add(newLanguage);
        developer.log('[LanguageScreen LOG] CharacterListScreen: Added new language: ${newLanguage.name}');
      }

      final languagesToSaveJson = jsonEncode(storedLanguages.map((e) => e.toJson()).toList());
      await prefs.setString('languages', languagesToSaveJson);
      developer.log('[LanguageScreen LOG] CharacterListScreen: Languages saved successfully to SharedPreferences.');

      if (mounted) {
        developer.log('[LanguageScreen LOG] CharacterListScreen: Popping with newLanguage: ${newLanguage.name}');
        Navigator.pop(context, newLanguage.toJson());
      }
    } else {
      developer.log('[LanguageScreen LOG] CharacterListScreen: Cannot save an empty language (no characters defined).');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add at least one character to save the language.')),
      );
    }
  }

  Future<void> _playMorseCode(bool isVibrate, bool isFlash) async {
    developer.log('[LanguageScreen LOG] CharacterListScreen: _playMorseCode called. Vibrate: $isVibrate, Flash: $isFlash, Morse: $currentMorseCode');
    if (currentMorseCode.isEmpty) {
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
    developer.log('[LanguageScreen LOG] CharacterListScreen: Playback: hasVibrator: $hasVibrator, hasTorch: $hasTorch');

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
      developer.log('[LanguageScreen LOG] CharacterListScreen: Playback: Existing playback detected, attempting to cancel.');
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
      final morseElements = currentMorseCode.replaceAll('·', '.').replaceAll('−', '-').split('');
      developer.log('[LanguageScreen LOG] CharacterListScreen: Playback: Starting new playback for: "$currentMorseCode"');

      for (int i = 0; i < morseElements.length; i++) {
        if (_isPlaybackCancelled) {
          developer.log('[LanguageScreen LOG] CharacterListScreen: Playback: Cancellation requested, breaking loop.');
          break;
        }

        final element = morseElements[i];
        bool isLastElementOfSequence = (i == morseElements.length - 1);
        bool nextElementIsSeparator = !isLastElementOfSequence &&
            (morseElements[i + 1] == ' ' || morseElements[i + 1] == '/');
        developer.log('[LanguageScreen LOG] CharacterListScreen: Playback: Processing element "$element" (Index: $i)');

        if (element == '.' || element == '-') {
          int duration = (element == '.') ? DOT_DURATION_MS : DASH_DURATION_MS;
          developer.log('[LanguageScreen LOG] CharacterListScreen: Playback: Element is dot/dash, duration: $duration ms');

          if (isFlash && (hasTorch ?? false)) {
            try {
              await TorchLight.enableTorch();
              developer.log('[LanguageScreen LOG] CharacterListScreen: Playback: Torch ON');
            } on Exception catch (e) {
              developer.log('[LanguageScreen LOG] CharacterListScreen: Error enabling torch: $e');
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
              developer.log('[LanguageScreen LOG] CharacterListScreen: Playback: Vibrating for $duration ms');
            } on Exception catch (e) {
              developer.log('[LanguageScreen LOG] CharacterListScreen: Error vibrating: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not vibrate: ${e.toString().split(':')[0]}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }

          await Future.delayed(Duration(milliseconds: duration));
          developer.log('[LanguageScreen LOG] CharacterListScreen: Playback: Waited for ON duration.');

          if (_isPlaybackCancelled) {
            break;
          }

          if (isFlash && (hasTorch ?? false)) {
            try {
              await TorchLight.disableTorch();
              developer.log('[LanguageScreen LOG] CharacterListScreen: Playback: Torch OFF');
            } on Exception catch (e) {
              developer.log('[LanguageScreen LOG] CharacterListScreen: Error disabling torch: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not disable flashlight: ${e.toString().split(':')[0]}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }

          if (!isLastElementOfSequence && !nextElementIsSeparator) {
            developer.log('[LanguageScreen LOG] CharacterListScreen: Playback: Waiting for inter-element gap: $ELEMENT_GAP_MS ms');
            await Future.delayed(Duration(milliseconds: ELEMENT_GAP_MS));
          }
        } else if (element == ' ') {
          developer.log('[LanguageScreen LOG] CharacterListScreen: Playback: Waiting for inter-character gap: $CHAR_GAP_MS ms');
          await Future.delayed(Duration(milliseconds: CHAR_GAP_MS));
        } else if (element == '/') {
          developer.log('[LanguageScreen LOG] CharacterListScreen: Playback: Waiting for inter-word gap: $WORD_GAP_MS ms');
          await Future.delayed(Duration(milliseconds: WORD_GAP_MS));
        }

        if (_isPlaybackCancelled) {
          break;
        }
      }
    }).whenComplete(() async {
      developer.log('[LanguageScreen LOG] CharacterListScreen: Playback: Playback completed or cancelled.');
      if (isFlash && (await TorchLight.isTorchAvailable() ?? false)) {
        try {
          await TorchLight.disableTorch();
          developer.log('[LanguageScreen LOG] CharacterListScreen: Playback: Ensuring torch is off on complete/cancel.');
        } on Exception catch (e) {
          developer.log('[LanguageScreen LOG] CharacterListScreen: Error ensuring torch is off on complete/cancel: $e');
        }
      }
      _currentPlaybackFuture = null;
      _isPlaybackCancelled = false;
      developer.log('[LanguageScreen LOG] CharacterListScreen: Playback: Playback state reset.');
    });
  }

  void _flashMorseCode(String morseCode) {
    developer.log('[LanguageScreen LOG] CharacterListScreen: _flashMorseCode called for: $morseCode');
    setState(() {
      currentMorseCode = morseCode;
    });
    _playMorseCode(false, true);
  }

  void _vibrateMorseCode(String morseCode) {
    developer.log('[LanguageScreen LOG] CharacterListScreen: _vibrateMorseCode called for: $morseCode');
    setState(() {
      currentMorseCode = morseCode;
    });
    _playMorseCode(true, false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 60,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Text(
                          'New language',
                          style: TextStyle(
                            color: Color(0xFF707070),
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 15),
                        child: GestureDetector(
                          onTap: () {
                            developer.log('[LanguageScreen LOG] CharacterListScreen: Close button tapped (no save).');
                            Navigator.pop(context, null);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            child: Icon(
                              Icons.close,
                              color: Color(0xFF0B0E10),
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 17),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                          child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                  color: Color(0xFF5BA188), borderRadius: BorderRadius.circular(100)))),
                      SizedBox(width: 5),
                      Expanded(
                          child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                  color: Color(0xFF5BA188), borderRadius: BorderRadius.circular(100)))),
                      SizedBox(width: 5),
                      Expanded(
                          child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                  color: Color(0xFF5BA188), borderRadius: BorderRadius.circular(100)))),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    developer.log('[LanguageScreen LOG] CharacterListScreen: Back button tapped (no save).');
                    Navigator.pop(context, null);
                  },
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios, size: 10, color: Color(0xFF838383)),
                        SizedBox(width: 4),
                        Text(
                          'Back',
                          style: TextStyle(
                            color: Color(0xFF838383),
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          ...characters.map((char) => _buildCharacterItem(char)).toList(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.only(top: 20, bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  offset: Offset(0, -1),
                  blurRadius: 26,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildAddButton(),
                      SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: Color(0xFFD9D9D9)),
                          ),
                          child: TextField(
                            controller: _charController,
                            maxLength: 1,
                            decoration: InputDecoration(
                              hintText: 'Enter character...',
                              hintStyle: TextStyle(
                                color: Color(0xFFA6A6A6),
                                fontSize: 16,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                              counterText: '',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  width: 318,
                  height: 54,
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (mounted) {
                                    setState(() {
                                      currentMorseCode += '·';
                                    });
                                  }
                                },
                                child: Container(
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFCDCDCD),
                                    borderRadius: BorderRadius.circular(11),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.28),
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 15,
                                      height: 15,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 9),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (mounted) {
                                    setState(() {
                                      currentMorseCode += '−';
                                    });
                                  }
                                },
                                child: Container(
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFCDCDCD),
                                    borderRadius: BorderRadius.circular(11),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.28),
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 25,
                                      height: 2.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          if (mounted) {
                            setState(() {
                              if (currentMorseCode.isNotEmpty) {
                                currentMorseCode = currentMorseCode.substring(0, currentMorseCode.length - 1);
                              }
                            });
                          }
                        },
                        child: Container(
                          width: 69,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Color(0xFFCDCDCD),
                            borderRadius: BorderRadius.circular(11),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.28),
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.backspace,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  currentMorseCode.isEmpty ? 'Enter Morse code...' : currentMorseCode,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: currentMorseCode.isEmpty ? 17 : 34,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: 20),
                GestureDetector(
                  onTap: _saveAndClose,
                  child: Container(
                    width: 330,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Color(0xFF4CB0D9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Save and add',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 25),
                Container(
                  height: 21,
                  child: Center(
                    child: Container(
                      width: 153,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Color(0x61353535),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterItem(Map<String, String> character) {
    return GestureDetector(
      onTap: () => _startEditing(character),
      child: Container(
        margin: EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            Container(
              width: 55,
              height: 50,
              padding: EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Color(0xFFD9D9D9)),
              ),
              child: Center(
                child: Text(
                  character['char']!,
                  style: TextStyle(
                    color: Color(0xFF0B0E10),
                    fontSize: 16,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 50,
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Color(0xFFD9D9D9)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      character['code']!,
                      style: TextStyle(
                        color: Color(0xFF0B0E10),
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _flashMorseCode(character['code']!),
                          child: Container(
                            width: 24,
                            height: 24,
                            child: Icon(
                              Icons.flash_on,
                              color: Color(0xFF4CB0D9),
                              size: 16,
                            ),
                          ),
                        ),
                        SizedBox(width: 11),
                        GestureDetector(
                          onTap: () => _vibrateMorseCode(character['code']!),
                          child: Container(
                            width: 24,
                            height: 24,
                            child: Icon(
                              Icons.vibration,
                              color: Color(0xFF4CB0D9),
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                developer.log('[LanguageScreen LOG] Character item delete tapped for: ${character['char']}');
                if (mounted) {
                  setState(() {
                    characters.remove(character);
                    if (editingCharacter['char'] == character['char']) {
                      editingCharacter = {};
                      _charController.clear();
                      currentMorseCode = '';
                    }
                  });
                }
              },
              child: Container(
                width: 50,
                height: 50,
                padding: EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Color(0xFFD9D9D9)),
                ),
                child: Icon(
                  Icons.delete,
                  color: Color(0xFFEB3208),
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _addOrUpdateCharacter,
      child: Container(
        width: 55,
        height: 50,
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Color(0xFF4CB0D9),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Center(
          child: Icon(
            Icons.add,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    );
  }
}