import 'package:cloud_firestore/cloud_firestore.dart';

class Chapter {
  final String id;
  final String mangaId;
  final String title;
  final int number;
  final List<String> pages;
  final DateTime createdAt;

  Chapter({
    required this.id,
    required this.mangaId,
    required this.title,
    required this.number,
    required this.pages,
    required this.createdAt,
  });

  factory Chapter.fromFirestore(Map<String, dynamic> data, String id) {
    return Chapter(
      id: id,
      mangaId: data['mangaId'] as String,
      title: data['title'] as String,
      number: data['number'] as int,
      pages: List<String>.from(data['pages'] as List),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'mangaId': mangaId,
      'title': title,
      'number': number,
      'pages': pages,
      'createdAt': createdAt,
    };
  }
}
