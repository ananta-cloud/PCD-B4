import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../widgets/auth_widgets.dart';
import 'register_screen.dart';
import '../main.dart';
import '../services/mongo_service.dart';
import '../services/hive_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

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
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email dan Password harus diisi!')),
      );
      return;
    }

    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      bool success = await MongoService.loginUser(email, password);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        // Simpan sesi login ke Hive agar persisten
        await HiveUtils.loginUser(
          email: email,
          name: MongoService.currentUserEmail ?? email,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login Berhasil!')),
        );
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MainShell(),
            transitionsBuilder: (context, anim, secondaryAnim, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kredensial salah. Cek email dan password.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      // Ini akan menampilkan ERROR ASLI ke layar HP Anda
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ERROR SERVER: $e'), backgroundColor: Colors.red),
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
                      Text('ReceiptSync', style: AppTextStyles.headlineXl()),
                      const SizedBox(height: 8),
                      Text('Intelligent edge extraction.', style: AppTextStyles.bodyMd()),
                      const SizedBox(height: 48),
                      // Form card
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: AppColors.outlineVariant.withValues(alpha: 0.6)),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('EMAIL ADDRESS', style: AppTextStyles.labelCaps()),
                            const SizedBox(height: 8),
                            AuthTextField(
                              controller: _emailCtrl,
                              hintText: 'user@organization.com',
                              prefixIcon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('PASSWORD', style: AppTextStyles.labelCaps()),
                                TextButton(
                                  onPressed: () {},
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Forgot?',
                                    style: AppTextStyles.label(color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
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
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            const SizedBox(height: 24),
                            AuthPrimaryButton(
                              label: 'Authenticate',
                              isLoading: _isLoading,
                              onTap: _authenticate,
                            ),
                            // HAPUS AuthOrDivider dan SizedBox di sini
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('New to ReceiptSync? ', style: AppTextStyles.bodyMd()),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RegisterScreen()),
                            ),
                            child: Text(
                              'Register Account',
                              style: AppTextStyles.bodyMd(color: AppColors.primary)
                                  .copyWith(fontWeight: FontWeight.w600),
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