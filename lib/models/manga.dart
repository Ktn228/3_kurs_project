import 'package:cloud_firestore/cloud_firestore.dart';
import 'chapter.dart';

class Chapter {
  final String id;
  final String mangaId;
  final String title;
  final List<String> pages;
  final int number;
  final DateTime createdAt;

  Chapter({
    required this.id,
    required this.mangaId,
    required this.title,
    required this.pages,
    required this.number,
    required this.createdAt,
  });

  factory Chapter.fromFirestore(Map<String, dynamic> data, String id) {
    return Chapter(
      id: id,
      mangaId: data['mangaId'] as String,
      title: data['title'] as String,
      pages: List<String>.from(data['pages'] as List),
      number: data['number'] as int,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'mangaId': mangaId,
      'title': title,
      'pages': pages,
      'number': number,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class Manga {
  final String id;
  final String title;
  final String description;
  final String coverImageBase64;
  final DateTime createdAt;
  List<Chapter> chapters;

  Manga({
    required this.id,
    required this.title,
    required this.description,
    required this.coverImageBase64,
    required this.createdAt,
    this.chapters = const [],
  });

  factory Manga.fromFirestore(Map<String, dynamic> data, String id) {
    return Manga(
      id: id,
      title: data['title'] as String,
      description: data['description'] as String,
      coverImageBase64: data['coverImageBase64'] as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'coverImageBase64': coverImageBase64,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Manga copyWith({
    String? id,
    String? title,
    String? description,
    String? coverImageBase64,
    DateTime? createdAt,
    List<Chapter>? chapters,
  }) {
    return Manga(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      coverImageBase64: coverImageBase64 ?? this.coverImageBase64,
      createdAt: createdAt ?? this.createdAt,
      chapters: chapters ?? this.chapters,
    );
  }
}
