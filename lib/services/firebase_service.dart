import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../models/manga.dart';
import '../models/user.dart';
import '../models/chapter.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  Future<List<Manga>> getMangas() async {
    final snapshot = await _firestore.collection('mangas').get();
    return snapshot.docs
        .map((doc) => Manga.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  Future<String> imageToBase64(XFile image) async {
    final bytes = await image.readAsBytes();
    return base64Encode(bytes);
  }

  Future<String> addManga(
      String title, String description, XFile coverImage) async {
    // Валидация
    if (title.trim().isEmpty) {
      throw Exception('Название не может быть пустым');
    }
    if (description.trim().isEmpty) {
      throw Exception('Описание не может быть пустым');
    }
    if (coverImage == null) {
      throw Exception('Обложка не выбрана');
    }

    final bytes = await coverImage.readAsBytes();
    print('Размер файла: \\${bytes.length} байт, путь: \\${coverImage.path}');
    if (!(coverImage.path.endsWith('.jpg') ||
        coverImage.path.endsWith('.jpeg') ||
        coverImage.path.endsWith('.png'))) {
      throw Exception('Разрешены только изображения JPG и PNG.');
    }
    final base64String = base64Encode(bytes);

    if (base64String.length > 900000) {
      throw Exception('Изображение слишком большое. Выберите файл поменьше.');
    }

    final data = {
      'title': title.trim(),
      'description': description.trim(),
      'coverImageBase64': base64String,
      'createdAt': FieldValue.serverTimestamp(),
    };
    print('Добавление манги: $data');

    final mangaRef = await _firestore.collection('mangas').add(data);
    return mangaRef.id;
  }

  Future<String> addChapter(
      String mangaId, String title, List<XFile> pages) async {
    try {
      final List<String> pageBase64Strings = [];
      for (final page in pages) {
        final bytes = await page.readAsBytes();
        pageBase64Strings.add(base64Encode(bytes));
      }

      // Get the current number of chapters for this manga
      final chaptersSnapshot = await _firestore
          .collection('chapters')
          .where('mangaId', isEqualTo: mangaId)
          .get();
      final chapterNumber = chaptersSnapshot.docs.length + 1;

      // Create the chapter document
      final chapterRef = await _firestore.collection('chapters').add({
        'mangaId': mangaId,
        'title': title,
        'number': chapterNumber,
        'pages': pageBase64Strings,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return chapterRef.id;
    } catch (e) {
      print('Error adding chapter: $e');
      rethrow;
    }
  }

  Future<void> updateManga(
    String mangaId, {
    String? title,
    String? description,
    XFile? coverImage,
  }) async {
    final Map<String, dynamic> updateData = {};
    if (title != null) updateData['title'] = title;
    if (description != null) updateData['description'] = description;
    if (coverImage != null) {
      final bytes = await coverImage.readAsBytes();
      updateData['coverImageBase64'] = base64Encode(bytes);
    }

    await _firestore.collection('mangas').doc(mangaId).update(updateData);
  }

  Future<void> updateChapter(
    String chapterId, {
    String? title,
    List<XFile>? pages,
  }) async {
    final Map<String, dynamic> updateData = {};
    if (title != null) updateData['title'] = title;
    if (pages != null) {
      final List<String> pageBase64Strings = [];
      for (final page in pages) {
        final bytes = await page.readAsBytes();
        pageBase64Strings.add(base64Encode(bytes));
      }
      updateData['pages'] = pageBase64Strings;
    }

    await _firestore.collection('chapters').doc(chapterId).update(updateData);
  }

  Future<void> deleteManga(String id) async {
    await _firestore.collection('mangas').doc(id).delete();
  }

  Future<void> deleteChapter(String chapterId) async {
    await _firestore.collection('chapters').doc(chapterId).delete();
  }

  Future<XFile?> pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    return image;
  }

  Future<List<XFile>> pickMultipleImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    return images;
  }

  // --- USER & ROLES ---
  Future<AppUser?> getUser(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return null;
    return AppUser.fromFirestore(userDoc.data()!, userDoc.id);
  }

  Future<void> updateUserRole(String userId, String role) async {
    await _firestore.collection('users').doc(userId).update({'role': role});
  }

  // --- BOOKMARKS ---
  Future<void> toggleBookmark(String userId, String chapterId) async {
    final userRef = _firestore.collection('users').doc(userId);
    final userDoc = await userRef.get();
    final bookmarks =
        Map<String, String>.from(userDoc.data()?['bookmarks'] ?? {});
    if (bookmarks[chapterId] == chapterId) {
      bookmarks.remove(chapterId);
    } else {
      bookmarks[chapterId] = chapterId;
    }
    await userRef.update({'bookmarks': bookmarks});
  }

  Future<bool> isChapterBookmarked(
      String userId, String mangaId, String chapterId) async {
    final user = await getUser(userId);
    if (user == null) return false;
    return user.bookmarks[mangaId] == chapterId;
  }

  // --- FAVORITES ---
  Future<void> toggleFavorite(String userId, String mangaId) async {
    final userRef = _firestore.collection('users').doc(userId);
    final userDoc = await userRef.get();
    final favorites = List<String>.from(userDoc.data()?['favorites'] ?? []);
    if (favorites.contains(mangaId)) {
      favorites.remove(mangaId);
    } else {
      favorites.add(mangaId);
    }
    await userRef.update({'favorites': favorites});
  }

  Future<bool> isMangaFavorite(String userId, String mangaId) async {
    final user = await getUser(userId);
    if (user == null) return false;
    return user.favorites.contains(mangaId);
  }
}
