import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/mongo_service.dart';
import '../main.dart'; 
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    // Buka box session yang kita simpan saat login
    var sessionBox = await Hive.openBox('session');
    String? savedUserId = sessionBox.get('userId');
    String? savedEmail = sessionBox.get('email');

    // Jika data sesi ditemukan, user dianggap sudah login (bisa dipakai OFFLINE)
    if (savedUserId != null && savedEmail != null) {
      MongoService.currentUserId = savedUserId;
      MongoService.currentUserEmail = savedEmail;
      _isLoggedIn = true;
    }

    // Hentikan loading dan perbarui tampilan
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black, // Sesuaikan dengan warna app Anda
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // Jika sudah pernah login, langsung masuk ke MainShell (halaman utama).
    // Jika belum, arahkan ke LoginScreen.
    return _isLoggedIn ? const MainShell() : const LoginScreen();
  }
}