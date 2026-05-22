import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../widgets/auth_widgets.dart';
import '../controllers/auth_controller.dart';
import 'login_screen.dart';
import '../main.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  // ── Controller ──────────────────────────────────────────────────────────
  late final AuthController _authCtrl;

  // ── Animasi (tetap di View) ─────────────────────────────────────────────
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _authCtrl = AuthController();
    _authCtrl.addListener(_onControllerChanged);

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
    _authCtrl.removeListener(_onControllerChanged);
    _authCtrl.dispose();
    _fadeCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  // ── View Actions ────────────────────────────────────────────────────────
  Future<void> _onSignUp() async {
    final success = await _authCtrl.signUp(
      _nameCtrl.text,
      _emailCtrl.text,
      _passwordCtrl.text,
    );
    if (!mounted || !success) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const MainShell(),
        transitionsBuilder: (context, anim, secondaryAnim, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  AuthGradientAccent(),
                  const SizedBox(height: 32),
                  AuthAppLogo(),
                  const SizedBox(height: 24),
                  Text(
                    'Create account',
                    style: AppTextStyles.headlineXl(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Start automating your expense\ntracking instantly with Edge AI.',
                    style: AppTextStyles.bodyMd(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  _Label('Full Name'),
                  const SizedBox(height: 8),
                  AuthTextField(
                    controller: _nameCtrl,
                    hintText: 'John Doe',
                    prefixIcon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 18),
                  _Label('Work Email'),
                  const SizedBox(height: 8),
                  AuthTextField(
                    controller: _emailCtrl,
                    hintText: 'john@company.com',
                    prefixIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 18),
                  _Label('Password'),
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
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: 28),
                  AuthPrimaryButton(
                    label: 'SIGN UP NOW',
                    isLoading: _authCtrl.isLoading,
                    onTap: _onSignUp,
                  ),
                  const SizedBox(height: 24),
                  AuthOrDivider(),
                  const SizedBox(height: 24),
                  AuthGoogleButton(onTap: _onSignUp),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: AppTextStyles.bodyMd(),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        ),
                        child: Text(
                          'Log in',
                          style: AppTextStyles.bodyMd(color: AppColors.primary)
                              .copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primary,
                          ),
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
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: AppTextStyles.bodyMd(color: AppColors.onSurface),
        ),
      );
}
