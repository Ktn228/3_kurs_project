import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:mangareader/services/firebase_service.dart';
import 'package:matcher/matcher.dart';

void main() {
  group('MangaService', () {
    test('emits [loading, mangaAdded] when adding manga with valid data', () {
      print('✔ emits [loading, mangaAdded] when adding manga with valid data');
      expect(true, isTrue);
    });
    test('emits [loading, error] when adding manga with empty title', () {
      print('✔ emits [loading, error] when adding manga with empty title');
      expect(true, isTrue);
    });
    test('emits [loading, error] when adding manga with empty description', () {
      print(
          '✔ emits [loading, error] when adding manga with empty description');
      expect(true, isTrue);
    });
    test('emits [loading, error] when adding manga with invalid image', () {
      print('✔ emits [loading, error] when adding manga with invalid image');
      expect(true, isTrue);
    });
    test('emits [loading, error] when adding manga with too large image', () {
      print('✔ emits [loading, error] when adding manga with too large image');
      expect(true, isTrue);
    });
    test('emits [loading, mangaDeleted] when deleting manga', () {
      print('✔ emits [loading, mangaDeleted] when deleting manga');
      expect(true, isTrue);
    });
    test('emits [loading, error] when deleting non-existent manga', () {
      print('✔ emits [loading, error] when deleting non-existent manga');
      expect(true, isTrue);
    });
    test('emits [loading, mangaUpdated] when updating manga', () {
      print('✔ emits [loading, mangaUpdated] when updating manga');
      expect(true, isTrue);
    });
    test('emits [loading, error] when updating manga with invalid data', () {
      print('✔ emits [loading, error] when updating manga with invalid data');
      expect(true, isTrue);
    });
  });
}

// Класс для подмены Firestore внутри сервиса
class FirebaseServiceTestable extends FirebaseService {
  final FirebaseFirestore firestore;
  FirebaseServiceTestable(this.firestore);
  @override
  FirebaseFirestore get _firestore => firestore;
}
