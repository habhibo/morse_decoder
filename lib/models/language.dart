import 'dart:convert';

class Language {
  String name;
  String? category;
  Map<String, String> characters; // Map of character to its morse code

  Language({
    required this.name,
    this.category,
    this.characters = const {},
  });

  // Convert a Language object into a Map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'characters': characters,
    };
  }

  // Convert a Map into a Language object.
  factory Language.fromJson(Map<String, dynamic> json) {
    return Language(
      name: json['name'],
      category: json['category'],
      characters: Map<String, String>.from(json['characters'] ?? {}),
    );
  }

  @override
  String toString() {
    return 'Language(name: $name, category: $category, characters: $characters)';
  }
}