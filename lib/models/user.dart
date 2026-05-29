/// User model untuk Hive local database
class User {
  final String id;
  final String email;
  final String name;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  bool isLoggedIn;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.photoUrl,
    required this.createdAt,
    this.lastLoginAt,
    this.isLoggedIn = false,
  });

  /// Copy with method untuk membuat user baru dengan field yang diubah
  User copyWith({
    String? id,
    String? email,
    String? name,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isLoggedIn,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    );
  }

  @override
  String toString() =>
      'User(id: $id, email: $email, name: $name, isLoggedIn: $isLoggedIn)';
}
