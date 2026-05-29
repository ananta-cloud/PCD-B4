import 'package:hive/hive.dart';
import '../models/user.dart';
import '../services/hive_service.dart';

/// Repository untuk akses data User menggunakan Hive local database.
class UserRepository {
  /// Dapatkan Hive box
  static Box<User> get _box => HiveService.usersBox;

  // ── CRUD Operations ────────────────────────────────────────────────────

  /// Simpan user baru
  Future<void> addUser(User user) async {
    await _box.put(user.id, user);
  }

  /// Ambil user berdasarkan ID
  User? getUser(String id) {
    return _box.get(id);
  }

  /// Ambil semua users
  List<User> getAllUsers() {
    return _box.values.toList();
  }

  /// Update user yang sudah ada
  Future<void> updateUser(User user) async {
    await _box.put(user.id, user);
  }

  /// Hapus user berdasarkan ID
  Future<void> deleteUser(String id) async {
    await _box.delete(id);
  }

  /// Hapus semua users
  Future<void> deleteAllUsers() async {
    await _box.clear();
  }

  // ── Query operations ───────────────────────────────────────────────────

  /// Ambil user yang sedang login
  User? getCurrentLoggedInUser() {
    try {
      final users = _box.values.where((u) => u.isLoggedIn).toList();
      return users.isNotEmpty ? users.first : null;
    } catch (e) {
      print('Error getting logged in user: $e');
      return null;
    }
  }

  /// Cek apakah ada user yang sedang login
  bool hasLoggedInUser() {
    return getCurrentLoggedInUser() != null;
  }

  /// Cari user berdasarkan email
  User? getUserByEmail(String email) {
    try {
      final users = _box.values.where((u) => u.email == email).toList();
      return users.isNotEmpty ? users.first : null;
    } catch (e) {
      print('Error finding user by email: $e');
      return null;
    }
  }

  /// Update status login user
  Future<void> updateLoginStatus(String userId, bool isLoggedIn) async {
    final user = _box.get(userId);
    if (user != null) {
      final updatedUser = user.copyWith(
        isLoggedIn: isLoggedIn,
        lastLoginAt: isLoggedIn ? DateTime.now() : user.lastLoginAt,
      );
      await _box.put(userId, updatedUser);
    }
  }

  /// Logout semua users (set isLoggedIn = false)
  Future<void> logoutAllUsers() async {
    for (final user in _box.values) {
      final updatedUser = user.copyWith(isLoggedIn: false);
      await _box.put(user.id, updatedUser);
    }
  }

  /// Jumlah total users
  int getTotalUsers() => _box.length;

  /// Jumlah users yang pernah login
  int getLoggedInUsersCount() {
    return _box.values.where((u) => u.lastLoginAt != null).length;
  }

  /// Cari users berdasarkan nama (case-insensitive)
  List<User> searchByName(String query) {
    final searchLower = query.toLowerCase();
    return _box.values
        .where((u) => u.name.toLowerCase().contains(searchLower))
        .toList();
  }

  /// Dapatkan user dengan activity terbaru
  User? getLastActiveUser() {
    try {
      final users = _box.values.toList();
      if (users.isEmpty) return null;
      users.sort((a, b) {
        final aTime = a.lastLoginAt ?? a.createdAt;
        final bTime = b.lastLoginAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
      return users.first;
    } catch (e) {
      print('Error getting last active user: $e');
      return null;
    }
  }

  // ── Statistics ─────────────────────────────────────────────────────────

  /// Dapatkan statistik users
  Map<String, dynamic> getUserStats() {
    return {
      'total_users': _box.length,
      'logged_in_users': _box.values.where((u) => u.isLoggedIn).length,
      'users_with_photo': _box.values.where((u) => u.photoUrl != null).length,
    };
  }
}
