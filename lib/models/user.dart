class AppUser {
  final String id;
  final String email;
  final String password;
  final String displayName;
  final String role;
  final Map<String, String> bookmarks;
  final List<String> favorites;
  final String? avatar;
  final bool twoFactorEnabled;

  AppUser({
    required this.id,
    required this.email,
    required this.password,
    required this.displayName,
    required this.role,
    this.bookmarks = const {},
    this.favorites = const [],
    this.avatar,
    this.twoFactorEnabled = false,
  });

  bool get isAdmin => role == 'admin';
  bool get isModerator => role == 'moderator' || isAdmin;
  bool get isUser => role == 'user' || isModerator;

  factory AppUser.fromFirestore(Map<String, dynamic> data, String id) {
    List<String> safeList(dynamic value) {
      if (value is List) {
        return value.whereType<String>().toList();
      }
      return [];
    }

    // Защита: если bookmarks — List, то делаем пустой Map, если Map — преобразуем
    final rawBookmarks = data['bookmarks'];
    final bookmarks = rawBookmarks is Map
        ? Map<String, String>.from(rawBookmarks)
        : <String, String>{};
    return AppUser(
      id: id,
      email: data['email'] ?? '',
      password: data['password'] ?? '',
      displayName: data['displayName'] ?? '',
      role: data['role'] ?? 'user',
      bookmarks: bookmarks,
      favorites: safeList(data['favorites']),
      avatar: data['avatar'] as String?,
      twoFactorEnabled: data['twoFactorEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'email': email,
      'password': password,
      'displayName': displayName,
      'role': role,
      'favorites': favorites,
      'bookmarks': bookmarks,
      'avatar': avatar,
      'twoFactorEnabled': twoFactorEnabled,
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? password,
    String? displayName,
    String? role,
    List<String>? favorites,
    Map<String, String>? bookmarks,
    String? avatar,
    bool? twoFactorEnabled,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      password: password ?? this.password,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      favorites: favorites ?? this.favorites,
      bookmarks: bookmarks ?? this.bookmarks,
      avatar: avatar ?? this.avatar,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
    );
  }
}
