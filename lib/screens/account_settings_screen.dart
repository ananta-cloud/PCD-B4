import 'package:flutter/material.dart';
import '../services/mongo_service.dart';
import '../widgets/auth_widgets.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _updatePassword() async {
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password baru tidak cocok!')));
      return;
    }

    setState(() => _isLoading = true);
    bool success = await MongoService.changePassword(_oldPassCtrl.text, _newPassCtrl.text);
    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password berhasil diubah!')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengubah password. Cek password lama Anda.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ganti Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            AuthTextField(controller: _oldPassCtrl, hintText: 'Password Lama', obscureText: true),
            const SizedBox(height: 16),
            AuthTextField(controller: _newPassCtrl, hintText: 'Password Baru', obscureText: true),
            const SizedBox(height: 16),
            AuthTextField(controller: _confirmPassCtrl, hintText: 'Konfirmasi Password Baru', obscureText: true),
            const SizedBox(height: 24),
            AuthPrimaryButton(label: 'Simpan Password', isLoading: _isLoading, onTap: _updatePassword),
          ],
        ),
      ),
    );
  }
}