import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class FavoriteMessage {
  final int id;
  final String text;
  final String morseCode;
  bool isFavorited;
  final bool isRTL;

  FavoriteMessage({
    required this.id,
    required this.text,
    required this.morseCode,
    this.isFavorited = false,
    this.isRTL = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'morseCode': morseCode,
      'isFavorited': isFavorited,
      'isRTL': isRTL,
    };
  }

  factory FavoriteMessage.fromJson(Map<String, dynamic> json) {
    return FavoriteMessage(
      id: json['id'] as int,
      text: json['text'] as String,
      morseCode: json['morseCode'] as String,
      isFavorited: json['isFavorited'] ?? false,
      isRTL: json['isRTL'] ?? false,
    );
  }
}

class FavoritesManager {
  static final FavoritesManager _instance = FavoritesManager._internal();
  factory FavoritesManager() => _instance;
  FavoritesManager._internal();

  static const String _key = 'favorite_messages';
  List<FavoriteMessage> _favoriteMessages = [];

  List<FavoriteMessage> get favoriteMessages => _favoriteMessages;

  Future<void> loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? favoritesJson = prefs.getString(_key);
      debugPrint('Loading favorites: $favoritesJson');

      if (favoritesJson != null && favoritesJson.isNotEmpty) {
        List<dynamic> favoritesList = json.decode(favoritesJson);
        _favoriteMessages = favoritesList
            .map((json) => FavoriteMessage.fromJson(json as Map<String, dynamic>))
            .toList();
        debugPrint('Loaded ${_favoriteMessages.length} favorites');
      } else {
        debugPrint('No saved favorites found, initializing with sample data');
        _favoriteMessages = [
          FavoriteMessage(
            id: 1,
            text: "Привет как твои дела?",
            morseCode: "·--· ·-· ·· ·-- · - -·- ·- -·- - ·-- --- ·· -·· · ·-·· ·- ··--··",
            isFavorited: true,
          ),
          FavoriteMessage(
            id: 2,
            text: "Hallo, wie geht's dir?",
            morseCode: "···· ·- ·-·· ·-·· ---   ·-- ·· ·   --· · ···· -   ·····   -·· ·· ·-·   ··--··",
            isFavorited: true,
          ),
          FavoriteMessage(
            id: 3,
            text: "هذا رسالة طويلة تم إنشاؤها بواسطة شخص جيد",
            morseCode: "···· ·- - ···· ·- ·-· ·· ... ·- ·-·· ·- - ·- ·-- ·· ·-·· ·-·· ···· - ··- -- ·· -· ... ···· ·- ·- ···· -··· ·· ·-- ·- ··· ·· - ... ···· ·- -·- ···· ... .--- ·- -.-- -.-- ·· -··",
            isFavorited: true,
            isRTL: true,
          ),
        ];
        await saveFavorites();
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

  Future<void> saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String favoritesJson = json.encode(
        _favoriteMessages.map((message) => message.toJson()).toList(),
      );
      await prefs.setString(_key, favoritesJson);
      debugPrint('Saved favorites: $favoritesJson');
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  Future<void> addFavorite(String text, String morseCode, {bool isRTL = false}) async {
    try {
      int newId = _favoriteMessages.isEmpty
          ? 1
          : _favoriteMessages.map((msg) => msg.id).reduce((a, b) => a > b ? a : b) + 1;

      FavoriteMessage newMessage = FavoriteMessage(
        id: newId,
        text: text,
        morseCode: morseCode,
        isFavorited: true,
        isRTL: isRTL,
      );

      _favoriteMessages.add(newMessage);
      await saveFavorites();
      debugPrint('Added favorite: ${newMessage.text}, ID: ${newMessage.id}');
    } catch (e) {
      debugPrint('Error adding favorite: $e');
    }
  }

  Future<void> removeFavorite(int id) async {
    try {
      _favoriteMessages.removeWhere((message) => message.id == id);
      await saveFavorites();
      debugPrint('Removed favorite with ID: $id');
    } catch (e) {
      debugPrint('Error removing favorite: $e');
    }
  }

  Future<void> toggleFavorite(int id) async {
    try {
      int index = _favoriteMessages.indexWhere((msg) => msg.id == id);
      if (index != -1) {
        _favoriteMessages[index].isFavorited = !_favoriteMessages[index].isFavorited;
        if (!_favoriteMessages[index].isFavorited) {
          _favoriteMessages.removeAt(index);
        }
        await saveFavorites();
        debugPrint('Toggled favorite with ID: $id, isFavorited: ${_favoriteMessages[index].isFavorited}');
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  bool isTextInFavorites(String text) {
    return _favoriteMessages.any((message) => message.text == text);
  }
}