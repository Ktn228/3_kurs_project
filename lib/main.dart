import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'models/manga.dart';
import 'services/firebase_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'models/user.dart';
import 'package:crypto/crypto.dart';
import 'dart:math';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manga Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: Colors.deepPurple,
          secondary: Colors.orange,
          surface: Colors.grey[900]!,
          background: Colors.black,
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
          onBackground: Colors.white,
          onError: Colors.white,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
        cardTheme: CardTheme(
          color: Colors.grey[900],
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.deepPurple,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[800],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        dialogTheme: DialogTheme(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.grey[800],
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const MangaListScreen(),
    );
  }
}

class MangaListScreen extends StatefulWidget {
  final AppUser? currentUser;

  const MangaListScreen({
    super.key,
    this.currentUser,
  });

  @override
  State<MangaListScreen> createState() => _MangaListScreenState();
}

class _MangaListScreenState extends State<MangaListScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showAuthDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final displayNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;
    bool isLogin = true;

    // Функция для валидации email
    String? validateEmail(String? value) {
      if (value == null || value.isEmpty) {
        return 'Введите email';
      }
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(value)) {
        return 'Введите корректный email';
      }
      return null;
    }

    Future<void> _showPasswordResetCodeDialog(String email) async {
      final codeController = TextEditingController();
      final newPasswordController = TextEditingController();
      final resetFormKey = GlobalKey<FormState>();
      bool resetLoading = false;
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Ввод кода и нового пароля'),
            content: Form(
              key: resetFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: codeController,
                    decoration:
                        const InputDecoration(labelText: 'Код из email'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: newPasswordController,
                    decoration:
                        const InputDecoration(labelText: 'Новый пароль'),
                    obscureText: true,
                    validator: (v) =>
                        v == null || v.length < 6 ? 'Минимум 6 символов' : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: resetLoading
                    ? null
                    : () async {
                        if (!resetFormKey.currentState!.validate()) return;
                        setState(() => resetLoading = true);
                        try {
                          await resetPassword(
                            email,
                            codeController.text.trim(),
                            newPasswordController.text.trim(),
                          );
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Пароль успешно изменён!')),
                          );
                        } catch (e) {
                          setState(() => resetLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ошибка: $e')),
                          );
                        }
                      },
                child: const Text('Сменить пароль'),
              ),
            ],
          ),
        ),
      );
    }

    Future<void> _showForgotPasswordDialog() async {
      final forgotEmailController = TextEditingController();
      final forgotFormKey = GlobalKey<FormState>();
      bool forgotLoading = false;
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Сброс пароля'),
            content: Form(
              key: forgotFormKey,
              child: TextFormField(
                controller: forgotEmailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: validateEmail,
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: forgotLoading
                    ? null
                    : () async {
                        if (!forgotFormKey.currentState!.validate()) return;
                        setState(() => forgotLoading = true);
                        try {
                          await sendPasswordResetCode(
                              forgotEmailController.text.trim());
                          Navigator.pop(context);
                          _showPasswordResetCodeDialog(
                              forgotEmailController.text.trim());
                        } catch (e) {
                          setState(() => forgotLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ошибка: $e')),
                          );
                        }
                      },
                child: const Text('Отправить код'),
              ),
            ],
          ),
        ),
      );
    }

    final user = await showDialog<AppUser>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isLogin ? 'Вход' : 'Регистрация'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isLogin) ...[
                      TextFormField(
                        controller: displayNameController,
                        decoration: const InputDecoration(labelText: 'Имя'),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Введите имя' : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: validateEmail,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(labelText: 'Пароль'),
                      obscureText: true,
                      validator: (v) => v == null || v.length < 6
                          ? 'Минимум 6 символов'
                          : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: const Text('Забыли пароль?'),
                ),
                if (isLogin)
                  TextButton(
                    onPressed: () => setState(() => isLogin = false),
                    child: const Text('Нет аккаунта? Зарегистрироваться'),
                  ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() => loading = true);
                          try {
                            AppUser? user;
                            if (isLogin) {
                              final users = await FirebaseFirestore.instance
                                  .collection('users')
                                  .where('email',
                                      isEqualTo: emailController.text.trim())
                                  .where('password',
                                      isEqualTo: hashPassword(
                                          passwordController.text.trim()))
                                  .get();
                              if (users.docs.isNotEmpty) {
                                final userData = users.docs.first.data();
                                print('User data from Firestore: $userData');
                                user = AppUser.fromFirestore(
                                    userData, users.docs.first.id);

                                print(
                                    'User role after fromFirestore: ${user.role}');

                                if (user.twoFactorEnabled) {
                                  // Генерируем и сохраняем 2FA код
                                  final twoFactorCode = generate2FACode();
                                  await save2FACode(user.id, twoFactorCode);
                                  // Отправляем код на email
                                  await send2FACodeToEmail(
                                      user.email, twoFactorCode);
                                  // Показываем диалог ввода кода
                                  final isValid = await show2FADialog(context);
                                  if (isValid != null) {
                                    // Проверяем введённый код
                                    final isCodeValid =
                                        await verify2FACode(user.id, isValid);
                                    if (isCodeValid) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('Вход выполнен успешно')),
                                      );
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                MangaListScreen(
                                                    currentUser: user)),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Неверный код подтверждения')),
                                      );
                                    }
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Вход выполнен успешно')),
                                  );
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            MangaListScreen(currentUser: user)),
                                  );
                                }
                              } else {
                                print(
                                    'Пользователь не найден или неверный пароль');
                                throw Exception(
                                    'Пользователь не найден или неверный пароль');
                              }
                            } else {
                              // Проверяем, не существует ли уже пользователь с таким email
                              final existingUsers = await FirebaseFirestore
                                  .instance
                                  .collection('users')
                                  .where('email',
                                      isEqualTo: emailController.text.trim())
                                  .get();

                              if (existingUsers.docs.isNotEmpty) {
                                throw Exception(
                                    'Пользователь с таким email уже существует');
                              }

                              final newUser = AppUser(
                                id: DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                                email: emailController.text.trim(),
                                password: passwordController.text.trim(),
                                displayName: displayNameController.text.trim(),
                                role: 'user',
                                twoFactorEnabled: false,
                              );
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(newUser.id)
                                  .set(newUser
                                      .copyWith(
                                          password:
                                              hashPassword(newUser.password))
                                      .toFirestore());
                              user = newUser;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Регистрация успешна: ${user.email}')),
                              );
                              Navigator.pop(context, user);
                            }
                          } catch (e) {
                            setState(() => loading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ошибка: $e')),
                            );
                          }
                        },
                  child: Text(isLogin ? 'Войти' : 'Зарегистрироваться'),
                ),
              ],
            );
          },
        );
      },
    );
    if (user != null) {
      setState(() => _currentUser = user);
    }
  }

  Future<void> _updateUserState() async {
    if (_currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.id)
          .get();
      if (mounted) {
        setState(() {
          _currentUser = AppUser.fromFirestore(userDoc.data()!, userDoc.id);
        });
      }
    }
  }

  Future<void> _toggleBookmark(String mangaId, String chapterId) async {
    if (_currentUser == null) return;
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(_currentUser!.id);
    final userDoc = await userRef.get();
    final rawBookmarks = userDoc.data()?['bookmarks'];
    final bookmarks = rawBookmarks is Map
        ? Map<String, String>.from(rawBookmarks)
        : <String, String>{};

    if (bookmarks[mangaId] == chapterId) {
      bookmarks.remove(mangaId);
    } else {
      bookmarks[mangaId] = chapterId;
    }

    await userRef.update({'bookmarks': bookmarks});
    await _updateUserState();
  }

  Future<void> _toggleFavorite(String mangaId) async {
    if (_currentUser == null) return;
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(_currentUser!.id);
    final userDoc = await userRef.get();
    final favorites = List<String>.from(userDoc.data()?['favorites'] ?? []);
    if (favorites.contains(mangaId)) {
      favorites.remove(mangaId);
    } else {
      favorites.add(mangaId);
    }
    await userRef.update({'favorites': favorites});
    await _updateUserState();
  }

  Future<void> _addManga() async {
    final coverImage = await _firebaseService.pickImage();
    if (coverImage != null) {
      try {
        await _firebaseService.addManga(
          _titleController.text,
          _descriptionController.text,
          coverImage,
        );
        _titleController.clear();
        _descriptionController.clear();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    }
  }

  Future<void> setBookmark(String mangaId, String chapterId) async {
    if (_currentUser == null) return;
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(_currentUser!.id);
    final userDoc = await userRef.get();
    final rawBookmarks = userDoc.data()?['bookmarks'];
    final bookmarks = rawBookmarks is Map
        ? Map<String, String>.from(rawBookmarks)
        : <String, String>{};
    bookmarks[mangaId] = chapterId;
    await userRef.update({'bookmarks': bookmarks});
    await _updateUserState();
  }

  Future<void> removeBookmark(String mangaId) async {
    if (_currentUser == null) return;
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(_currentUser!.id);
    final userDoc = await userRef.get();
    final rawBookmarks = userDoc.data()?['bookmarks'];
    final bookmarks = rawBookmarks is Map
        ? Map<String, String>.from(rawBookmarks)
        : <String, String>{};
    bookmarks.remove(mangaId);
    await userRef.update({'bookmarks': bookmarks});
    await _updateUserState();
  }

  bool isBookmarked(String mangaId, String chapterId) {
    if (_currentUser == null) return false;
    return _currentUser!.bookmarks[mangaId] == chapterId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Manga Reader'),
        actions: [
          if (_currentUser == null) ...[
            TextButton.icon(
              onPressed: _showAuthDialog,
              icon: const Icon(Icons.login),
              label: const Text('Вход'),
            ),
          ] else ...[
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(
                      user: _currentUser!,
                      onLogout: () => setState(() => _currentUser = null),
                      onAvatarUpdate: (avatar) {
                        setState(() {
                          _currentUser = _currentUser!.copyWith(avatar: avatar);
                        });
                      },
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      backgroundImage: _currentUser!.avatar != null
                          ? MemoryImage(base64Decode(_currentUser!.avatar!))
                          : null,
                      child: _currentUser!.avatar == null
                          ? Text(
                              _currentUser!.displayName.isNotEmpty
                                  ? _currentUser!.displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(_currentUser!.displayName,
                        style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ]
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Поиск манги...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('mangas').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: \\${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final query = _searchQuery;
                final mangas = snapshot.data!.docs.map((doc) {
                  return Manga.fromFirestore(
                      doc.data() as Map<String, dynamic>, doc.id);
                }).where((manga) {
                  return query.isEmpty ||
                      manga.title.toLowerCase().contains(query) ||
                      manga.description.toLowerCase().contains(query);
                }).toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: mangas.length,
                  itemBuilder: (context, index) {
                    final manga = mangas[index];
                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MangaDetailScreen(
                                manga: manga,
                                currentUser: _currentUser,
                                onUserUpdate: _updateUserState,
                              ),
                            ),
                          );
                          await _updateUserState();
                          setState(() {});
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                                child: manga.coverImageBase64.isNotEmpty
                                    ? Image.memory(
                                        base64Decode(manga.coverImageBase64),
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: Colors.grey[800],
                                        child: const Center(
                                          child: Icon(
                                            Icons.image_not_supported,
                                            color: Colors.white54,
                                            size: 48,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    manga.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('chapters')
                                        .where('mangaId', isEqualTo: manga.id)
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return const Text(
                                          '...',
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        );
                                      }
                                      final count = snapshot.data!.docs.length;
                                      return Text(
                                        '$count глав',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: (_currentUser != null &&
              (_currentUser!.role == 'admin' ||
                  _currentUser!.role == 'moderator'))
          ? FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Добавить мангу'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Название',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Описание',
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Отмена'),
                      ),
                      TextButton(
                        onPressed: () {
                          _addManga();
                          Navigator.pop(context);
                        },
                        child: const Text('Добавить'),
                      ),
                    ],
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class MangaDetailScreen extends StatefulWidget {
  Manga manga;
  AppUser? currentUser;
  final Function() onUserUpdate;

  MangaDetailScreen({
    super.key,
    required this.manga,
    this.currentUser,
    required this.onUserUpdate,
  });

  @override
  State<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _chapterTitleController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _reviewController = TextEditingController();
  XFile? _newCoverImage;
  bool _isFavorite = false;
  int _rating = 5;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.manga.title;
    _descriptionController.text = widget.manga.description;
    _checkFavorite();
  }

  @override
  void dispose() {
    _chapterTitleController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _checkFavorite() async {
    if (widget.currentUser != null) {
      setState(() {
        _isFavorite = widget.currentUser!.favorites.contains(widget.manga.id);
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (widget.currentUser == null) return;
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUser!.id);
    final userDoc = await userRef.get();
    final favorites = List<String>.from(userDoc.data()?['favorites'] ?? []);

    if (favorites.contains(widget.manga.id)) {
      favorites.remove(widget.manga.id);
    } else {
      favorites.add(widget.manga.id);
    }

    await userRef.update({'favorites': favorites});
    setState(() {
      _isFavorite = !_isFavorite;
    });

    // Update user state in parent
    widget.onUserUpdate();
  }

  Future<void> _addChapter() async {
    final pages = await _firebaseService.pickMultipleImages();
    if (pages.isNotEmpty) {
      try {
        final chapterId = await _firebaseService.addChapter(
          widget.manga.id,
          _chapterTitleController.text,
          pages,
        );
        _chapterTitleController.clear();

        // Update manga state after adding chapter
        final chaptersSnapshot = await FirebaseFirestore.instance
            .collection('chapters')
            .where('mangaId', isEqualTo: widget.manga.id)
            .orderBy('number')
            .get();

        if (mounted) {
          final updatedChapters = chaptersSnapshot.docs
              .map((doc) => Chapter.fromFirestore(
                  doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          setState(() {
            widget.manga = widget.manga.copyWith(chapters: updatedChapters);
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка при добавлении главы: $e')),
          );
        }
      }
    }
  }

  Future<void> _updateManga() async {
    try {
      await _firebaseService.updateManga(
        widget.manga.id,
        title: _titleController.text,
        description: _descriptionController.text,
        coverImage: _newCoverImage,
      );
      setState(() {
        _newCoverImage = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _showEditDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Manga'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final image = await _firebaseService.pickImage();
                  if (image != null) {
                    setState(() {
                      _newCoverImage = image;
                    });
                  }
                },
                child: const Text('Change Cover Image'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, {
                'title': _titleController.text,
                'description': _descriptionController.text,
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _updateManga();
    }
  }

  Future<void> _deleteManga() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить мангу?'),
        content: const Text(
            'Это действие нельзя отменить. Все главы также будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Delete all chapters first
        final chaptersSnapshot = await FirebaseFirestore.instance
            .collection('chapters')
            .where('mangaId', isEqualTo: widget.manga.id)
            .get();

        for (var doc in chaptersSnapshot.docs) {
          await doc.reference.delete();
        }

        // Delete the manga
        await FirebaseFirestore.instance
            .collection('mangas')
            .doc(widget.manga.id)
            .delete();

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Манга успешно удалена')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка при удалении: $e')),
          );
        }
      }
    }
  }

  Future<void> _addReview() async {
    if (widget.currentUser == null || _reviewController.text.trim().isEmpty)
      return;

    final reviewsQuery = await FirebaseFirestore.instance
        .collection('reviews')
        .where('mangaId', isEqualTo: widget.manga.id)
        .where('userId', isEqualTo: widget.currentUser!.id)
        .limit(1)
        .get();

    if (reviewsQuery.docs.isNotEmpty) {
      // Обновляем существующий отзыв
      final reviewId = reviewsQuery.docs.first.id;
      await FirebaseFirestore.instance
          .collection('reviews')
          .doc(reviewId)
          .update({
        'text': _reviewController.text.trim(),
        'rating': _rating,
        'createdAt': Timestamp.now(),
      });
    } else {
      // Добавляем новый отзыв
      await FirebaseFirestore.instance.collection('reviews').add({
        'mangaId': widget.manga.id,
        'userId': widget.currentUser!.id,
        'userName': widget.currentUser!.displayName,
        'text': _reviewController.text.trim(),
        'rating': _rating,
        'createdAt': Timestamp.now(),
      });
    }
    _reviewController.clear();
    setState(() {});
  }

  Future<void> _deleteReview(String reviewId) async {
    await FirebaseFirestore.instance
        .collection('reviews')
        .doc(reviewId)
        .delete();
    setState(() {});
  }

  Future<void> _editReview(
      String reviewId, String newText, int newRating) async {
    await FirebaseFirestore.instance
        .collection('reviews')
        .doc(reviewId)
        .update({
      'text': newText,
      'rating': newRating,
      'createdAt': Timestamp.now(),
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.manga.title),
          backgroundColor: Theme.of(context).colorScheme.surface,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Главы'),
              Tab(text: 'Отзывы'),
            ],
          ),
          actions: [
            if (widget.currentUser != null) ...[
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.blue : null,
                ),
                onPressed: _toggleFavorite,
              ),
            ],
            if (widget.currentUser != null &&
                (widget.currentUser!.role == 'admin' ||
                    widget.currentUser!.role == 'moderator')) ...[
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _showEditDialog,
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _deleteManga,
              ),
            ],
          ],
        ),
        body: TabBarView(
          children: [
            // Главы
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.manga.coverImageBase64.isNotEmpty)
                    Image.memory(
                      base64Decode(widget.manga.coverImageBase64),
                      width: double.infinity,
                      height: 300,
                      fit: BoxFit.cover,
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.manga.title,
                                style:
                                    Theme.of(context).textTheme.headlineMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.manga.description,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('reviews')
                              .where('mangaId', isEqualTo: widget.manga.id)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final reviews = snapshot.data!.docs
                                .map((doc) => Review.fromFirestore(
                                    doc.data() as Map<String, dynamic>, doc.id))
                                .toList();
                            if (reviews.isEmpty) {
                              return const Text('Нет оценок');
                            }
                            final ratings = reviews
                                .where((r) => r.rating != null)
                                .map((r) => r.rating!)
                                .toList();
                            final avg = ratings.isNotEmpty
                                ? ratings.reduce((a, b) => a + b) /
                                    ratings.length
                                : 0.0;
                            return Row(
                              children: [
                                ...List.generate(
                                    5,
                                    (i) => Icon(
                                          i < avg.round()
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: Colors.amber,
                                        )),
                                const SizedBox(width: 8),
                                Text(avg.toStringAsFixed(1),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(width: 4),
                                Text('(${ratings.length})'),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        if (widget.currentUser != null &&
                            widget.currentUser!.bookmarks.isNotEmpty)
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('chapters')
                                .where(FieldPath.documentId,
                                    whereIn: widget.currentUser!.bookmarks
                                            .values.isEmpty
                                        ? ['_none_']
                                        : widget.currentUser!.bookmarks.values
                                            .toList())
                                .where('mangaId', isEqualTo: widget.manga.id)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const SizedBox.shrink();
                              }

                              final bookmarkedChapters = snapshot.data!.docs
                                  .map((doc) => Chapter.fromFirestore(
                                      doc.data() as Map<String, dynamic>,
                                      doc.id))
                                  .toList();

                              if (bookmarkedChapters.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Закладки',
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 16),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: bookmarkedChapters.length,
                                    itemBuilder: (context, index) {
                                      final chapter = bookmarkedChapters[index];
                                      final isBookmarked = widget.currentUser !=
                                              null &&
                                          widget.currentUser!
                                                  .bookmarks[widget.manga.id] ==
                                              chapter.id;
                                      final isModerator =
                                          widget.currentUser != null &&
                                              (widget.currentUser!.role ==
                                                      'admin' ||
                                                  widget.currentUser!.role ==
                                                      'moderator');
                                      return ListTile(
                                        leading: isBookmarked
                                            ? const Icon(Icons.bookmark,
                                                color: Colors.blue)
                                            : null,
                                        title: Text(
                                            'Chapter ${chapter.number}: ${chapter.title}'),
                                        subtitle: Text(
                                            '${chapter.pages.length} pages'),
                                        trailing: isModerator
                                            ? IconButton(
                                                icon: const Icon(Icons.delete,
                                                    color: Colors.red),
                                                onPressed: () async {
                                                  final confirm =
                                                      await showDialog<bool>(
                                                    context: context,
                                                    builder: (context) =>
                                                        AlertDialog(
                                                      title: const Text(
                                                          'Удалить главу?'),
                                                      content: const Text(
                                                          'Это действие нельзя отменить.'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context,
                                                                  false),
                                                          child: const Text(
                                                              'Отмена'),
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context,
                                                                  true),
                                                          child: const Text(
                                                              'Удалить',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .red)),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true) {
                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection('chapters')
                                                        .doc(chapter.id)
                                                        .delete();
                                                    setState(() {});
                                                  }
                                                },
                                              )
                                            : null,
                                        onTap: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  ChapterViewScreen(
                                                chapter: chapter,
                                                mangaTitle: widget.manga.title,
                                                currentUser: widget.currentUser,
                                                onUserUpdate:
                                                    widget.onUserUpdate,
                                              ),
                                            ),
                                          );
                                          await widget.onUserUpdate();
                                          if (widget.currentUser != null) {
                                            final userDoc =
                                                await FirebaseFirestore.instance
                                                    .collection('users')
                                                    .doc(widget.currentUser!.id)
                                                    .get();
                                            setState(() {
                                              widget.currentUser =
                                                  AppUser.fromFirestore(
                                                      userDoc.data()!,
                                                      userDoc.id);
                                            });
                                          }
                                        },
                                      );
                                    },
                                  ),
                                  const Divider(),
                                ],
                              );
                            },
                          ),
                        Text(
                          'Chapters',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('chapters')
                              .where('mangaId', isEqualTo: widget.manga.id)
                              .orderBy('number')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            final chapters = snapshot.data!.docs
                                .map((doc) => Chapter.fromFirestore(
                                    doc.data() as Map<String, dynamic>, doc.id))
                                .toList();

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: chapters.length,
                              itemBuilder: (context, index) {
                                final chapter = chapters[index];
                                final isBookmarked =
                                    widget.currentUser != null &&
                                        widget.currentUser!
                                                .bookmarks[widget.manga.id] ==
                                            chapter.id;
                                final isModerator =
                                    widget.currentUser != null &&
                                        (widget.currentUser!.role == 'admin' ||
                                            widget.currentUser!.role ==
                                                'moderator');
                                return ListTile(
                                  leading: isBookmarked
                                      ? const Icon(Icons.bookmark,
                                          color: Colors.blue)
                                      : null,
                                  title: Text(
                                      'Chapter ${chapter.number}: ${chapter.title}'),
                                  subtitle:
                                      Text('${chapter.pages.length} pages'),
                                  trailing: isModerator
                                      ? IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () async {
                                            final confirm =
                                                await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                    'Удалить главу?'),
                                                content: const Text(
                                                    'Это действие нельзя отменить.'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            context, false),
                                                    child: const Text('Отмена'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            context, true),
                                                    child: const Text('Удалить',
                                                        style: TextStyle(
                                                            color: Colors.red)),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              await FirebaseFirestore.instance
                                                  .collection('chapters')
                                                  .doc(chapter.id)
                                                  .delete();
                                              setState(() {});
                                            }
                                          },
                                        )
                                      : null,
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChapterViewScreen(
                                          chapter: chapter,
                                          mangaTitle: widget.manga.title,
                                          currentUser: widget.currentUser,
                                          onUserUpdate: widget.onUserUpdate,
                                        ),
                                      ),
                                    );
                                    await widget.onUserUpdate();
                                    if (widget.currentUser != null) {
                                      final userDoc = await FirebaseFirestore
                                          .instance
                                          .collection('users')
                                          .doc(widget.currentUser!.id)
                                          .get();
                                      setState(() {
                                        widget.currentUser =
                                            AppUser.fromFirestore(
                                                userDoc.data()!, userDoc.id);
                                      });
                                    }
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Отзывы
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.currentUser != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _reviewController,
                          decoration: const InputDecoration(
                            hintText: 'Оставьте отзыв...',
                            filled: true,
                            fillColor: Colors.grey,
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: List.generate(
                              5,
                              (index) => IconButton(
                                    icon: Icon(
                                      index < _rating
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                    ),
                                    onPressed: () =>
                                        setState(() => _rating = index + 1),
                                  )),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.send),
                          label: const Text('Отправить отзыв'),
                          onPressed: _addReview,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('reviews')
                          .where('mangaId', isEqualTo: widget.manga.id)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const SizedBox.shrink();
                        }
                        final reviews = snapshot.data!.docs
                            .map((doc) => Review.fromFirestore(
                                doc.data() as Map<String, dynamic>, doc.id))
                            .toList();
                        if (reviews.isEmpty) {
                          return const Center(child: Text('Нет отзывов'));
                        }
                        return ListView.builder(
                          itemCount: reviews.length,
                          itemBuilder: (context, index) {
                            final review = reviews[index];
                            final isMyReview = widget.currentUser != null &&
                                review.userId == widget.currentUser!.id;
                            final isModerator = widget.currentUser != null &&
                                (widget.currentUser!.role == 'admin' ||
                                    widget.currentUser!.role == 'moderator');
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          review.userName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Row(
                                          children: List.generate(
                                              5,
                                              (i) => Icon(
                                                    i < (review.rating ?? 0)
                                                        ? Icons.star
                                                        : Icons.star_border,
                                                    color: Colors.amber,
                                                    size: 18,
                                                  )),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(review.text),
                                    if (isMyReview || isModerator)
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          if (isMyReview)
                                            TextButton.icon(
                                              icon: const Icon(Icons.edit),
                                              label: const Text('Изменить'),
                                              onPressed: () async {
                                                final controller =
                                                    TextEditingController(
                                                        text: review.text);
                                                int editRating =
                                                    review.rating ?? 5;
                                                final newText =
                                                    await showDialog<String>(
                                                  context: context,
                                                  builder: (context) =>
                                                      AlertDialog(
                                                    title: const Text(
                                                        'Изменить отзыв'),
                                                    content: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        TextField(
                                                          controller:
                                                              controller,
                                                          maxLines: 3,
                                                        ),
                                                        const SizedBox(
                                                            height: 16),
                                                        Row(
                                                          children:
                                                              List.generate(
                                                                  5,
                                                                  (i) =>
                                                                      IconButton(
                                                                        icon:
                                                                            Icon(
                                                                          i < editRating
                                                                              ? Icons.star
                                                                              : Icons.star_border,
                                                                          color:
                                                                              Colors.amber,
                                                                        ),
                                                                        onPressed:
                                                                            () =>
                                                                                editRating = i + 1,
                                                                      )),
                                                        ),
                                                      ],
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context),
                                                        child: const Text(
                                                            'Отмена'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context,
                                                                controller
                                                                    .text),
                                                        child: const Text(
                                                            'Сохранить'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (newText != null &&
                                                    newText.trim().isNotEmpty) {
                                                  await _editReview(
                                                      review.id,
                                                      newText.trim(),
                                                      editRating);
                                                }
                                              },
                                            ),
                                          TextButton.icon(
                                            icon: const Icon(Icons.delete),
                                            label: const Text('Удалить'),
                                            onPressed: () =>
                                                _deleteReview(review.id),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: (widget.currentUser != null &&
                (widget.currentUser!.role == 'admin' ||
                    widget.currentUser!.role == 'moderator'))
            ? FloatingActionButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Добавить главу'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: _chapterTitleController,
                            decoration: const InputDecoration(
                              labelText: 'Название главы',
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Отмена'),
                        ),
                        TextButton(
                          onPressed: () {
                            _addChapter();
                            Navigator.pop(context);
                          },
                          child: const Text('Добавить'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }
}

class ChapterViewScreen extends StatefulWidget {
  final Chapter chapter;
  final String mangaTitle;
  AppUser? currentUser;
  final Function() onUserUpdate;

  ChapterViewScreen({
    super.key,
    required this.chapter,
    required this.mangaTitle,
    this.currentUser,
    required this.onUserUpdate,
  });

  @override
  State<ChapterViewScreen> createState() => _ChapterViewScreenState();
}

class _ChapterViewScreenState extends State<ChapterViewScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isBookmarked = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _checkBookmark();
  }

  Future<void> _checkBookmark() async {
    if (widget.currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUser!.id)
          .get();
      final rawBookmarks = userDoc.data()?['bookmarks'];
      final bookmarks = rawBookmarks is Map
          ? Map<String, String>.from(rawBookmarks)
          : <String, String>{};
      setState(() {
        _isBookmarked = bookmarks[widget.chapter.mangaId] == widget.chapter.id;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    if (widget.currentUser == null) return;

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUser!.id);

      final userDoc = await userRef.get();
      final rawBookmarks = userDoc.data()?['bookmarks'];
      final bookmarks = rawBookmarks is Map
          ? Map<String, String>.from(rawBookmarks)
          : <String, String>{};

      if (bookmarks[widget.chapter.mangaId] == widget.chapter.id) {
        bookmarks.remove(widget.chapter.mangaId);
      } else {
        bookmarks[widget.chapter.mangaId] = widget.chapter.id;
      }

      // Обновляем закладки в Firestore
      await userRef.update({
        'bookmarks': bookmarks,
      });

      // Update local state
      setState(() {
        _isBookmarked = bookmarks[widget.chapter.mangaId] == widget.chapter.id;
      });

      // Update user state in parent
      if (widget.currentUser != null) {
        final updatedUser = AppUser(
          id: widget.currentUser!.id,
          email: widget.currentUser!.email,
          password: widget.currentUser!.password,
          displayName: widget.currentUser!.displayName,
          role: widget.currentUser!.role,
          favorites: widget.currentUser!.favorites,
          bookmarks: bookmarks,
          avatar: widget.currentUser!.avatar,
          twoFactorEnabled: widget.currentUser!.twoFactorEnabled,
        );
        widget.currentUser = updatedUser;
        widget.onUserUpdate();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при обновлении закладки: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.mangaTitle} - ${widget.chapter.title}'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          if (widget.currentUser != null) ...[
            IconButton(
              icon: Icon(
                _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: _isBookmarked ? Colors.blue : null,
              ),
              onPressed: _toggleBookmark,
            ),
          ],
        ],
      ),
      body: PageView.builder(
        itemCount: widget.chapter.pages.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemBuilder: (context, index) {
          return Image.memory(
            base64Decode(widget.chapter.pages[index]),
            fit: BoxFit.contain,
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  'Страница ${_currentPage + 1} из ${widget.chapter.pages.length}'),
              if (widget.currentUser != null)
                IconButton(
                  icon: Icon(
                    _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: _isBookmarked ? Colors.blue : null,
                  ),
                  onPressed: _toggleBookmark,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserProfileScreen extends StatefulWidget {
  final AppUser user;
  final Function() onLogout;
  final Function(String) onAvatarUpdate;

  const UserProfileScreen({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onAvatarUpdate,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  AppUser? _currentUser;
  bool _isLoading = true;
  bool _isRequestingModerator = false;
  List<AppUser> _moderators = [];
  bool _isLoadingModerators = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      print('Loading current user...');
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.id)
          .get();

      if (userDoc.exists) {
        print('User document exists');
        final userData = userDoc.data()!;
        setState(() {
          _currentUser = AppUser.fromFirestore(userData, userDoc.id);
          _isLoading = false;
        });
        print('User loaded: ${_currentUser?.toFirestore()}');
      } else {
        print('User document does not exist');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestModeratorRole() async {
    if (_isRequestingModerator) return;

    setState(() {
      _isRequestingModerator = true;
    });

    try {
      // Проверяем, нет ли уже активной заявки
      final existingRequest = await FirebaseFirestore.instance
          .collection('moderator_requests')
          .where('userId', isEqualTo: _currentUser!.id)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('У вас уже есть активная заявка на модератора')),
        );
        return;
      }

      // Создаем новую заявку
      await FirebaseFirestore.instance.collection('moderator_requests').add({
        'userId': _currentUser!.id,
        'userName': _currentUser!.displayName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Заявка на модератора успешно отправлена')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при отправке заявки: $e')),
      );
    } finally {
      setState(() {
        _isRequestingModerator = false;
      });
    }
  }

  Future<void> _loadModerators() async {
    setState(() {
      _isLoadingModerators = true;
    });

    try {
      final moderatorsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['moderator', 'admin']).get();

      setState(() {
        _moderators = moderatorsSnapshot.docs
            .map((doc) => AppUser.fromFirestore(doc.data(), doc.id))
            .toList();
        _isLoadingModerators = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при загрузке модераторов: $e')),
      );
      setState(() {
        _isLoadingModerators = false;
      });
    }
  }

  Future<void> _showModeratorsList() async {
    await _loadModerators();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Управление модераторами'),
        content: SizedBox(
          width: double.maxFinite,
          child: _isLoadingModerators
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _moderators.length,
                  itemBuilder: (context, index) {
                    final moderator = _moderators[index];
                    return ListTile(
                      title: Text(moderator.displayName),
                      subtitle: Text(moderator.email),
                      trailing: moderator.role == 'admin'
                          ? const Text('Админ')
                          : IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _removeModeratorRole(moderator),
                            ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeModeratorRole(AppUser moderator) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение'),
        content: Text(
            'Вы уверены, что хотите снять роль модератора у пользователя ${moderator.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(moderator.id)
            .update({'role': 'user'});

        await _loadModerators();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Роль модератора успешно снята')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при снятии роли модератора: $e')),
        );
      }
    }
  }

  Future<void> _showModeratorRequests() async {
    try {
      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('moderator_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      if (!mounted) return;

      final requests = requestsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'userId': data['userId'],
          'userName': data['userName'],
          'createdAt': (data['createdAt'] as Timestamp).toDate(),
        };
      }).toList();

      // Сортируем заявки на клиенте
      requests.sort((a, b) =>
          (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));

      if (requests.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет активных заявок')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Заявки на модератора'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return Card(
                  child: ListTile(
                    title: Text(request['userName'] as String),
                    subtitle: Text(
                      'Подана: ${request['createdAt'].toString().split('.')[0]}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () => _handleModeratorRequest(
                            request['id'] as String,
                            request['userId'] as String,
                            true,
                            dialogContext,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _handleModeratorRequest(
                            request['id'] as String,
                            request['userId'] as String,
                            false,
                            dialogContext,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при загрузке заявок: $e')),
      );
    }
  }

  Future<void> _handleModeratorRequest(String requestId, String userId,
      bool approved, BuildContext dialogContext) async {
    try {
      // Обновляем статус заявки
      await FirebaseFirestore.instance
          .collection('moderator_requests')
          .doc(requestId)
          .update({
        'status': approved ? 'approved' : 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': _currentUser!.id,
      });

      if (approved) {
        // Обновляем роль пользователя
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'role': 'moderator'});
      }

      // Закрываем диалог
      Navigator.pop(dialogContext);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved ? 'Заявка одобрена' : 'Заявка отклонена',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при обработке заявки: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Пользователь не найден')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              widget.onLogout();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: _currentUser!.avatar != null
                            ? ClipOval(
                                child: Image.memory(
                                  base64Decode(_currentUser!.avatar!),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Text(
                                _currentUser!.displayName[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 40,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt,
                                color: Colors.white),
                            onPressed: () async {
                              final image = await FirebaseService().pickImage();
                              if (image != null) {
                                final bytes = await image.readAsBytes();
                                final base64String = base64Encode(bytes);
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(_currentUser!.id)
                                    .update({'avatar': base64String});
                                widget.onAvatarUpdate(base64String);
                                setState(() {
                                  _currentUser = _currentUser!
                                      .copyWith(avatar: base64String);
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentUser!.displayName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    _currentUser!.email,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Роль: ${_currentUser!.role}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (_currentUser!.role == 'user')
              Center(
                child: ElevatedButton.icon(
                  onPressed:
                      _isRequestingModerator ? null : _requestModeratorRole,
                  icon: _isRequestingModerator
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.admin_panel_settings),
                  label: Text(_isRequestingModerator
                      ? 'Отправка заявки...'
                      : 'Подать заявку на модератора'),
                ),
              ),
            if (_currentUser!.role == 'admin')
              Center(
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _showModeratorsList,
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Управление модераторами'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showModeratorRequests,
                      icon: const Icon(Icons.pending_actions),
                      label: const Text('Заявки на модератора'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            const Text(
              'Избранные манги:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('mangas')
                  .where(FieldPath.documentId,
                      whereIn: _currentUser!.favorites.isEmpty
                          ? ['_none_']
                          : _currentUser!.favorites)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final mangas = snapshot.data!.docs.map((doc) {
                  return Manga.fromFirestore(
                      doc.data() as Map<String, dynamic>, doc.id);
                }).toList();
                if (mangas.isEmpty) {
                  return const Center(child: Text('Нет избранных манг'));
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: mangas.length,
                  itemBuilder: (context, index) {
                    final manga = mangas[index];
                    return ListTile(
                      leading: manga.coverImageBase64.isNotEmpty
                          ? Image.memory(base64Decode(manga.coverImageBase64),
                              width: 40, height: 60, fit: BoxFit.cover)
                          : const Icon(Icons.book),
                      title: Text(manga.title),
                      subtitle: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('chapters')
                            .where('mangaId', isEqualTo: manga.id)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Text('...');
                          }
                          final count = snapshot.data!.docs.length;
                          return Text(
                            '$count глав',
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MangaDetailScreen(
                              manga: manga,
                              currentUser: _currentUser!,
                              onUserUpdate: () async {
                                await _loadCurrentUser();
                              },
                            ),
                          ),
                        );
                        await _loadCurrentUser();
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.lock),
              label: const Text('Изменить пароль'),
              onPressed: () {
                final newPasswordController = TextEditingController();
                final confirmPasswordController = TextEditingController();
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Изменить пароль'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: newPasswordController,
                          decoration:
                              const InputDecoration(labelText: 'Новый пароль'),
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: confirmPasswordController,
                          decoration: const InputDecoration(
                              labelText: 'Повторите пароль'),
                          obscureText: true,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Отмена'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final newPassword = newPasswordController.text.trim();
                          final confirmPassword =
                              confirmPasswordController.text.trim();
                          if (newPassword.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Пароль должен быть не менее 6 символов')),
                            );
                            return;
                          }
                          if (newPassword != confirmPassword) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Пароли не совпадают')),
                            );
                            return;
                          }
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(_currentUser!.id)
                              .update({'password': hashPassword(newPassword)});
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Пароль успешно изменён')),
                          );
                        },
                        child: const Text('Сохранить'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Двухфакторная аутентификация'),
              subtitle: const Text('Дополнительная защита вашего аккаунта'),
              value: _currentUser!.twoFactorEnabled,
              onChanged: (bool value) async {
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(_currentUser!.id)
                      .update({'twoFactorEnabled': value});

                  setState(() {
                    _currentUser =
                        _currentUser!.copyWith(twoFactorEnabled: value);
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(value
                          ? 'Двухфакторная аутентификация включена'
                          : 'Двухфакторная аутентификация выключена'),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Модель отзыва
class Review {
  final String id;
  final String mangaId;
  final String userId;
  final String userName;
  final String text;
  final int? rating;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.mangaId,
    required this.userId,
    required this.userName,
    required this.text,
    this.rating,
    required this.createdAt,
  });

  factory Review.fromFirestore(Map<String, dynamic> data, String id) {
    return Review(
      id: id,
      mangaId: data['mangaId'] as String,
      userId: data['userId'] as String,
      userName: data['userName'] as String,
      text: data['text'] as String,
      rating: data['rating'] as int?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'mangaId': mangaId,
      'userId': userId,
      'userName': userName,
      'text': text,
      'rating': rating,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

// Функция для хэширования пароля
String hashPassword(String password) {
  final bytes = utf8.encode(password);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

// Функция для генерации 6-значного кода
String generate2FACode() {
  final rand = Random();
  return List.generate(6, (_) => rand.nextInt(10)).join();
}

// Функция для отправки кода на email
Future<void> send2FACodeToEmail(String email, String code) async {
  try {
    // Настройки SMTP сервера (замените на свои)
    final smtpServer = SmtpServer(
      'smtp.gmail.com', // SMTP сервер
      port: 587, // Порт
      username: 'nikitusha167322@gmail.com', // Ваш email
      password: 'zezy nvpu gewl qonb ', // Пароль приложения
      ssl: false,
      allowInsecure: true,
    );

    // Создаем сообщение
    final message = Message()
      ..from = Address('nikitusha167322@gmail.com', 'Manga Reader')
      ..recipients.add(email)
      ..subject = 'Код подтверждения для входа'
      ..text = '''
Здравствуйте!

Ваш код подтверждения для входа в Manga Reader: $code

Код действителен в течение 5 минут.

С уважением,
Команда Manga Reader
''';

    // Отправляем сообщение
    final sendReport = await send(message, smtpServer);
    print('Message sent: ${sendReport.toString()}');
  } catch (e) {
    print('Error sending email: $e');
    // В случае ошибки выводим код в консоль для тестирования
    print('2FA code for $email: $code');
  }
}

// Функция для проверки 2FA кода
Future<bool> verify2FACode(String userId, String code) async {
  try {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (!userDoc.exists) return false;

    final userData = userDoc.data();
    if (userData == null) return false;

    final storedCode = userData['twoFactorCode'] as String?;
    final expiresAt = userData['twoFactorExpires'] as Timestamp?;

    if (storedCode == null || expiresAt == null) return false;
    if (DateTime.now().isAfter(expiresAt.toDate())) return false;

    // Очищаем код после проверки
    if (storedCode == code) {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'twoFactorCode': null,
        'twoFactorExpires': null,
      });
      return true;
    }

    return false;
  } catch (e) {
    print('Error verifying 2FA code: $e');
    return false;
  }
}

// Функция для сохранения 2FA кода в Firestore
Future<void> save2FACode(String userId, String code) async {
  final expiresAt = DateTime.now().add(Duration(minutes: 5));
  await FirebaseFirestore.instance.collection('users').doc(userId).update({
    'twoFactorCode': code,
    'twoFactorExpires': Timestamp.fromDate(expiresAt),
  });
}

// Функция для показа диалога ввода 2FA кода
Future<String?> show2FADialog(BuildContext context) async {
  final codeController = TextEditingController();
  String? code;
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Введите код подтверждения'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Код был отправлен на ваш email'),
          const SizedBox(height: 16),
          TextField(
            controller: codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              hintText: '6-значный код',
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            code = codeController.text.trim();
            Navigator.of(context).pop();
          },
          child: const Text('Подтвердить'),
        ),
      ],
    ),
  );
  return code;
}

// --- Логика сброса пароля ---
Future<void> sendPasswordResetCode(String email) async {
  final users = await FirebaseFirestore.instance
      .collection('users')
      .where('email', isEqualTo: email.trim())
      .get();
  if (users.docs.isEmpty) throw Exception('Пользователь не найден');
  final userId = users.docs.first.id;
  final code = generate2FACode();
  await save2FACode(userId, code);
  await send2FACodeToEmail(email, code);
}

Future<void> resetPassword(
    String email, String code, String newPassword) async {
  final users = await FirebaseFirestore.instance
      .collection('users')
      .where('email', isEqualTo: email.trim())
      .get();
  if (users.docs.isEmpty) throw Exception('Пользователь не найден');
  final userId = users.docs.first.id;
  final isValid = await verify2FACode(userId, code);
  if (!isValid) throw Exception('Неверный код');
  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .update({'password': hashPassword(newPassword)});
}
