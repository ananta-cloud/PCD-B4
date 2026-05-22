import 'package:flutter/foundation.dart';

/// Controller untuk LoginScreen dan RegisterScreen — mengelola state autentikasi.
///
/// Saat ini menggunakan fake delay. Nanti akan dihubungkan ke backend API.
class AuthController extends ChangeNotifier {
  bool _isLoading = false;

  /// True saat proses autentikasi sedang berjalan
  bool get isLoading => _isLoading;

  /// Autentikasi pengguna. Returns true jika berhasil.
  Future<bool> authenticate(String email, String password) async {
    if (_isLoading) return false;

    _isLoading = true;
    notifyListeners();

    // TODO: Ganti dengan panggilan API ke backend
    await Future.delayed(const Duration(milliseconds: 1200));

    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// Registrasi pengguna baru. Returns true jika berhasil.
  Future<bool> signUp(String name, String email, String password) async {
    if (_isLoading) return false;

    _isLoading = true;
    notifyListeners();

    // TODO: Ganti dengan panggilan API ke backend
    await Future.delayed(const Duration(milliseconds: 1200));

    _isLoading = false;
    notifyListeners();
    return true;
  }
}
