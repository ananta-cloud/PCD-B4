import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../widgets/auth_widgets.dart';
import '../services/mongo_service.dart'; // Import service MongoDB

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Animasi yang sama persis dengan LoginScreen
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // FUNGSI UNTUK REGISTER KE MONGODB
  Future<void> _register() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    // 1. Validasi Input
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email dan Password harus diisi!')),
      );
      return;
    }

    if (_isLoading) return;
    setState(() => _isLoading = true);

    // 2. Memanggil fungsi Register dari Service
    bool success = await MongoService.registerUser(email, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    // 3. Aksi setelah register
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akun berhasil dibuat! Silakan Login.')),
      );
      // Jika sukses, kembali ke halaman Login
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Register Gagal. Email mungkin sudah terdaftar.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      body: SafeArea(
        child: Stack(
          children: [
            // Grid background
            const Positioned.fill(child: AuthGridBackground()),
            FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 64),
                      AuthAppLogo(),
                      const SizedBox(height: 20),
                      Text('Create Account', style: AppTextStyles.headlineXl()),
                      const SizedBox(height: 8),
                      Text(
                        'Join ReceiptSync today.',
                        style: AppTextStyles.bodyMd(),
                      ),
                      const SizedBox(height: 48),
                      // Form card
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.outlineVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EMAIL ADDRESS',
                              style: AppTextStyles.labelCaps(),
                            ),
                            const SizedBox(height: 8),
                            AuthTextField(
                              controller: _emailCtrl,
                              hintText: 'user@organization.com',
                              prefixIcon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 20),
                            // Dihapus bagian tombol "Forgot Password" karena ini form Register
                            Text('PASSWORD', style: AppTextStyles.labelCaps()),
                            const SizedBox(height: 8),
                            AuthTextField(
                              controller: _passwordCtrl,
                              hintText: '••••••••',
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.onSurfaceVariant,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            AuthPrimaryButton(
                              label: 'Create Account',
                              isLoading: _isLoading,
                              onTap: _register,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: AppTextStyles.bodyMd(),
                          ),
                          GestureDetector(
                            // Kembali ke halaman sebelumnya (LoginScreen)
                            onTap: () => Navigator.pop(context),
                            child: Text(
                              'Log In',
                              style: AppTextStyles.bodyMd(
                                color: AppColors.primary,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
