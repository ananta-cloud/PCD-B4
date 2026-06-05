import 'package:flutter/material.dart';
import '../services/mongo_service.dart';
import '../services/hive_utils.dart';
import 'package:hive/hive.dart';

class AuthController extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Melakukan proses autentikasi (login)
  /// Return true jika berhasil, throw exception jika error
  Future<bool> authenticate(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      _errorMessage = 'Email dan Password harus diisi!';
      notifyListeners();
      return false;
    }

    if (_isLoading) return false;
    _setLoading(true);
    _errorMessage = null;

    try {
      bool success = await MongoService.loginUser(email, password);

      if (success) {
        // Simpan sesi login ke Hive agar persisten (Untuk AuthGate)
        var sessionBox = await Hive.openBox('session');
        await sessionBox.put('userId', MongoService.currentUserId ?? email);
        await sessionBox.put('email', MongoService.currentUserEmail ?? email);

        // Simpan ke userRepository juga
        await HiveUtils.loginUser(
          email: email,
          name: MongoService.currentUserEmail ?? email,
        );
        _setLoading(false);
        return true;
      } else {
        _errorMessage = 'Kredensial salah. Cek email dan password.';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'ERROR SERVER: $e';
      _setLoading(false);
      rethrow;
    }
  }

  /// Melakukan proses logout
  Future<void> logout() async {
    _setLoading(true);
    try {
      // 1. Hapus session di Hive (Untuk AuthGate)
      var sessionBox = await Hive.openBox('session');
      await sessionBox.clear();

      // 2. Logout dari User Repository
      await HiveUtils.logoutCurrentUser();

      // 3. Logout dari Mongo Service
      MongoService.logout();
    } finally {
      _setLoading(false);
    }
  }
}
